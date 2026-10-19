// Vita3K emulator project
// Copyright (C) 2026 Vita3K team
// SPDX-License-Identifier: GPL-2.0-or-later

#include <io/functions.h>
#include <io/io.h>
#include <kernel/state.h>
#include <kernel/thread/thread_state.h>
#include <mem/state.h>

#include <atomic>
#include <chrono>
#include <cstdlib>
#include <iostream>
#include <sstream>
#include <thread>

using namespace std::chrono_literals;

static void check(bool condition, const char *message) {
    if (!condition) {
        std::cerr << message << '\n';
        std::_Exit(1);
    }
}

static void wait_until_blocked(const ThreadStatePtr &thread, const std::atomic_bool &finished) {
    const auto deadline = std::chrono::steady_clock::now() + 1s;
    while (std::chrono::steady_clock::now() < deadline) {
        check(!finished.load(), "Empty blocking terminal returned without input");
        {
            const std::lock_guard lock(thread->mutex);
            if (thread->status == ThreadStatus::waiting)
                return;
        }
        std::this_thread::sleep_for(1ms);
    }
    check(false, "Terminal reader did not enter a kernel wait");
}

int main() {
    IOState io;
    KernelState kernel;
    MemState mem{};
    auto make_thread = [&](SceUID id) {
        auto thread = std::make_shared<ThreadState>(id, kernel, mem);
        thread->priority = 64;
        return thread;
    };
    auto open_terminal = [&](int flags) {
        const auto fd = open_file(io, "tty0:", flags, {}, "tty-test");
        check(fd >= 0, "Opening terminal failed");
        return fd;
    };

    char untouched = '?';
    const auto nonblocking = open_terminal(SCE_O_RDWR | SCE_O_NBLOCK);
    check(read_file(&untouched, io, nonblocking, 0, "tty-test") == 0, "Zero-byte terminal read must succeed");
    check(read_file(&untouched, io, nonblocking, 1, "tty-test") == SCE_ERROR_ERRNO_EAGAIN, "Empty nonblocking terminal must return EAGAIN");
    check(untouched == '?', "Empty read changed the destination");
    close_file(io, nonblocking, "tty-test");

    const auto first_fd = open_terminal(SCE_O_RDONLY);
    const auto second_fd = open_terminal(SCE_O_RDWR);
    auto first_thread = make_thread(1);
    auto second_thread = make_thread(2);
    std::atomic_bool first_done = false, second_done = false;
    int first_result = 0, second_result = 0;
    char first_byte = '?', second_byte = '?';
    std::thread first([&] {
        first_result = read_file(&first_byte, io, first_fd, 1, "tty-test", first_thread);
        first_done = true;
    });
    std::thread second([&] {
        second_result = read_file(&second_byte, io, second_fd, 1, "tty-test", second_thread);
        second_done = true;
    });
    wait_until_blocked(first_thread, first_done);
    wait_until_blocked(second_thread, second_done);
    close_file(io, first_fd, "tty-test");
    first.join();
    check(first_result == SCE_ERROR_ERRNO_EBADFD, "Closing the terminal did not cancel its read");
    check(!second_done.load(), "Closing one terminal cancelled another terminal's read");
    io_deinit(io);
    second.join();
    check(second_result == SCE_ERROR_ERRNO_EBADFD, "IO teardown did not cancel its read");
    check(first_byte == '?' && second_byte == '?', "Cancelled reads changed their destinations");

    const auto exiting_fd = open_terminal(SCE_O_RDONLY);
    auto exiting_thread = make_thread(3);
    std::atomic_bool exiting_done = false;
    std::thread exiting([&] {
        read_file(&untouched, io, exiting_fd, 1, "tty-test", exiting_thread);
        exiting_done = true;
    });
    wait_until_blocked(exiting_thread, exiting_done);
    exiting_thread->remove();
    exiting.join();
    check(exiting_done.load(), "Thread deletion did not release the terminal read");
    close_file(io, exiting_fd, "tty-test");

    const auto host_fd = open_terminal(SCE_O_RDONLY);
    std::istringstream input("abc");
    const auto old_state = std::cin.rdstate();
    auto *old_buffer = std::cin.rdbuf(input.rdbuf());
    char buffer[5] = { '?', '?', '?', '?', '?' };
    check(read_file(buffer, io, host_fd, sizeof(buffer), "tty-test") == 3, "Partial read reported bytes it did not read");
    check(buffer[0] == 'a' && buffer[2] == 'c' && buffer[3] == '?', "Partial read corrupted its destination");
    check(read_file(buffer, io, host_fd, 1, "tty-test") == 0, "Host EOF reported fabricated input");
    std::cin.rdbuf(old_buffer);
    std::cin.clear(old_state);
    close_file(io, host_fd, "tty-test");
    std::cout << "TTY read checks passed\n";
}

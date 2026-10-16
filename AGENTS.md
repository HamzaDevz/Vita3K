# AGENTS

Branche `odin3` du fork HamzaDevz/Vita3K : Vita3K Android optimisé pour l'AYN Odin 3 (Snapdragon 8 Elite,
Adreno 830, pilote Vulkan Qualcomm stock, Android 15). Jeu de référence : Uncharted: Golden Abyss `PCSF00012`
v1.03. Notes en français, code et commentaires en anglais comme upstream. Les lignes citées dérivent : revérifier.

## Règles

- Rien ne se code sans mesure sur l'Odin : le banc `tools/odin3` (`docs/Odin3.md`) juge chaque changement sur le
  vrai jeu, avant et après. Ni l'émulateur Android du Mac ni un PC ne remplacent l'Adreno.
- L'Odin est partagé avec d'autres sessions (Eden/Switch) : aucun lancement de jeu ni mesure sans le verrou
  `tools/odin3/lock.sh take <owner>` ; le rendre dès la série finie, ne jamais supprimer le verrou d'un autre.
  Ne jamais forcer l'arrêt d'un paquet Eden.
- Les fps ne suffisent pas : Uncharted tournait à 30 fps stables en x2 avec une image détruite. Un `shot` qui a
  une référence dans `tools/odin3/refs/<scénario>/` juge l'image (`BROKEN RENDER` au-delà de 10 % d'écart).
- Une session parallèle (autre jeu) travaille dans son propre worktree, avec son verrou (`LOCK_OWNER=<nom>`) et
  son paquet (`-PbenchSuffix=.<nom>` à la build, `PKG=org.vita3k.emulator.odin3.debug.<nom>` au banc).
- Une optimisation vaut pour tous les jeux : pas de condition par titre.
- Commits sur `odin3`, puis push vers `origin` (le fork) ; jamais vers `upstream` ni `plus`.
- Build de banc = `reldebug` (débogable, `org.vita3k.emulator.odin3.debug`) ; release = `release`. Une build
  locale empaquette `vita3k/shaders-builtin` avant que CMake ne l'ait copié : un nouveau shader intégré demande
  une seconde passe de Gradle (la CI copie d'abord, `.ci/build-android.sh`).

## Carte

- `android/` : app Kotlin (Compose). `MainActivity.kt` porte le hook de banc (extras `bench_install_*`, builds
  débogables seulement), `Emulator.java` l'activité de jeu (SDL), `InstallForegroundService.kt` les installations.
- `vita3k/android/jni/` : JNI ; `native_bootstrap.cpp` initialise `EmuEnvState` de façon asynchrone depuis la liste
  des jeux, `native_install.cpp` installe PUP, pkg et licences.
- `vita3k/renderer/src/vulkan/` : renderer Vulkan. Détection Adreno stock/Turnip dans `renderer.cpp` (majeur du
  pilote ≥ 100 = stock), couche de validation dans `renderer.cpp` (`validation-layer`), contournements Adreno
  stock dans `screen_renderer.cpp`, cache de pipelines dans `pipeline_cache.cpp`.
- `vita3k/renderer/src/` : synchro des surfaces (`sync.cpp`, `transfer.cpp`, `scene.cpp`) selon
  `memory-mapping`, `disable-surface-sync` et `high-accuracy`.
- `vita3k/config/include/config/config.h` : toutes les clés de `config.yml` et leurs défauts.
- `vita3k/packages/src/pkg.cpp` : installation des pkg ; une mise à jour se fusionne dans `ux0/app/<ID>`.
- `vita3k/ctrl/src/ctrl.cpp` : manettes SDL ; `vita3k/util/src/logging.cpp` : logs (logcat + fichier, flush à
  chaque message).
- `external/CMakeLists.txt` : hors `Release`, télécharge la couche de validation Khronos dans
  `android/prebuilt/`, que Gradle empaquette (`jniLibs`) dans toute build tant que le dossier existe.
- `tools/odin3/` : banc adb (verrou, installation, scénarios, mesures).

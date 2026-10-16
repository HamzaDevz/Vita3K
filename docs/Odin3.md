# Vita3K sur l'AYN Odin 3

Branche `odin3` : Vita3K Android réglé pour l'Odin 3 (Snapdragon 8 Elite, Adreno 830, pilote Vulkan Qualcomm, Android
15). Chaque changement se mesure sur la console, avec le vrai jeu, par `tools/odin3`.

## Préparer

1. Builder : dans `android/`, avec `JAVA_HOME=$(/usr/libexec/java_home -v 21) VCPKG_ROOT=~/vcpkg
   ANDROID_NDK_HOME=~/Library/Android/sdk/ndk/29.0.14206865 ANDROID_HOME=~/Library/Android/sdk
   PKG_CONFIG_LIBDIR=/var/empty PKG_CONFIG_PATH=`, lancer `./gradlew --no-daemon -q :app:assembleReldebug`
   (`-PbenchSuffix=.<nom>` pour une session parallèle).
2. Copier une fois dans `/sdcard/Download/vita3k-bench/` : `PSVUPDAT.PUP`, `PSP2UPDAT.PUP`, les pkg
   (`<ID>-....pkg`, patchs en `<ID>-patch.pkg`) et les licences `<ID>.rif`.
3. `tools/odin3/lock.sh take vita3k`, puis `tools/odin3/install.sh <apk>` : installe la build et la pointe sur
   l'installation partagée `/storage/emulated/0/vita3k-bench/vita`. Elle y installe d'abord firmware, polices, jeux
   puis patchs, ce qui manque seulement.

## Mesurer

`tools/odin3/run.sh <nom> [clé=valeur ...]` démarre le jeu du scénario avec ces clés de `config.yml`, restaure sa
sauvegarde, joue `scenarios/<SCENARIO>.txt` et écrit `runs/<nom>/summary.txt`. Pour chaque segment
`measure ... end`, il donne :

- fps, part des trames lentes et 1 % des pires trames (SurfaceFlinger) ;
- puissance, fréquences, températures ;
- threads les plus chargés du processus.

Un `shot` qui a une référence dans `refs/<scénario>/` est en plus comparé à une image juste : au-delà de 10 %
d'écart, `BROKEN RENDER`. La couche de validation est toujours forcée à `false`. `PKG=` mesure une autre build,
dont la configuration est rendue à la fin. Variables : `TARGET=60`, `COLD=1` (cache de shaders vide), `HOLD=1`
(garder le verrou pour une série), `LOCK_OWNER`, `PROFILE=<segment>:<s>` (simpleperf sur ce segment, dans un run
à part, vers `profile.txt`).

Ne jamais faire de capture pendant une mesure (SurfaceFlinger cale). Classer le goulot avant d'optimiser : thread
invité, thread de rendu (`SDLThread`), GPU, compilation de shaders ou synchronisation.

## Uncharted: Golden Abyss (PCSF00012 v1.03), scénario `uncharted-intro`

Le scénario part du point de contrôle du prologue après le tutoriel du journal : chargement, attente, marche.

- Le jeu est plafonné à 30 fps. Le prologue tient 30 fps en x1, x2 et x3, avec le GPU à 17, 35 et 55 % à 660 MHz.
  Les chargements font des à-coups de 90 à 150 ms, et le CPU y monte à 100 °C.
- « Injouable » venait de l'image, pas des fps. À partir de x2, les murs et Drake tournaient au bruit de couleurs
  avec de grands blocs noirs : 41 % d'écart à la référence en x2, 25 % en x3. Les copies « typeless » des tampons
  de lumière échantillonnaient de mauvaises données. Corrigé par la PR upstream #4027 : 0,3 à 0,5 % d'écart en x1,
  x2 et x3, à perf égale.
- `fps-hack=true` en x2 donne 60 fps à l'arrêt et 59,8 en marche, avec 1,1 % de trames au-delà de 25 ms et le GPU
  à 58 %.
- La couche de validation Vulkan, activée, coûte 0,9 W et fait passer les trames lentes de 1,1 à 1,8 % : elle est
  désactivée par défaut et la release ne l'embarque plus. La release (`odin3-r1`) tient 60 / 59,8 fps en x2.
- Vita3K Plus rend aussi juste en x2 et x3, mais consomme plus de CPU (4,6 W contre 3 W en x1).
- Le cache de shaders vide ne change presque rien sur ce scénario : la compilation asynchrone absorbe.

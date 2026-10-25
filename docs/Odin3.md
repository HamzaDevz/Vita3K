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

Chaque `shot`, référence ou non, est aussi fouillé (`glitch.py`) : blocs noirs, même rongeant l'image depuis un bord (`BLACK BLOCKS`), et aplats vert ou bleu fluo (`CORRUPT COLORS`). Un segment
sous 95 % de `TARGET` ou avec plus de 2 % de trames lentes est `BELOW TARGET`. La dernière ligne, `verdict`, compte
segments sous l'objectif, captures cassées et plantages. Une ligne `boot` relance le jeu : un parcours enchaîne ainsi
tout un jeu chapitre par chapitre, et un plantage n'y coûte que son chapitre (un log par boot). Une ligne
`suspend <s>` met la console en veille <s> secondes puis la réveille, comme un joueur entre deux sessions.

Tous les points de tous les jeux : `harvest.sh` copie chaque sauvegarde des vraies parties du joueur (carte SD) dans
`saves/player/<ID>/<date>`, une fois par sauvegarde distincte, sans rien lancer ; le relancer après chaque session de
jeu. `points.sh <nom> [clé=valeur ...]` rejoue sur une build chacun de ces points (le jeu charge la sauvegarde par ses
menus, `scenarios/continue-<ID>.txt`, puis joue environ 5 min : course, saut, regard, une capture toutes les 25 s)
et chaque parcours `scenarios/*-chapters.txt`, sur l'installation du joueur, à 60 fps visés, puis écrit un verdict
par point dans `runs/<nom>/verdict.txt`. Un jeu sans route `continue-<ID>` y est signalé : l'écrire.

Le prologue seul ne juge rien : Uncharted y était juste et montrait des carrés noirs plus loin. Un changement de rendu
ou de perf se juge sur le parcours complet du jeu (`uncharted-chapters`), pas sur un seul passage.

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
- Le profil du walk (`PROFILE=walk:25`) montrait 5 % des cycles du processus dans la fusion des blocs protégés
  (`add_protect`, thread de rendu) : corrigé, 10 % de cycles en moins en marche. Les erreurs de la couche de
  validation (sémaphores du swapchain, filtre linéaire sur la profondeur) sont corrigées aussi (`odin3-r2`).
- Vita3K Plus rend aussi juste en x2 et x3, mais consomme plus de CPU (4,6 W contre 3 W en x1).
- Le cache de shaders vide ne change presque rien sur ce scénario : la compilation asynchrone absorbe.
- Parcours complet (`uncharted-chapters`, release 9621858f, x1 + fps-hack, `TARGET=60`) : prologue et 34 chapitres,
  environ 1 min chacun, entre 58,3 et 60 fps. 11 segments sur 70 en saccades (2,2 à 5,1 % d'images au-delà de 25 ms,
  chapitres 5, 7, 9, 10, 14, 16, 18, 19, 26), 2 plantages (chapitres 17 et 21 : `createGraphicsPipeline` renvoie
  `ErrorUnknown`), aucun bloc noir sur 103 captures. Mais depuis la sauvegarde du chapitre 1 de Hamza (carte SD), les
  carrés noirs apparaissent après 1 min 30 de jeu continu et rongent jusqu'à 58 % de l'image (8 captures sur 10, à
  60 fps) : la corruption s'accumule image après image, une minute par point ne la voit pas. Les routes `continue-<ID>`
  jouent donc environ 5 min et le parcours 2 min 30 par chapitre (environ 2 h 30).

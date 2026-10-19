# Compatibilité Odin 3 : Vita3K (PS Vita)

Notre propre liste de compatibilité, tenue d'après nos tests sur l'AYN Odin 3 (Snapdragon 8 Elite, Adreno 830) avec notre build de la branche `odin3`. Chaque test met à jour la ligne du jeu : statut, mesure, date et commit testé.

Autres émulateurs : [Eden (Switch)](https://github.com/HamzaDevz/eden/blob/odin3/ODIN3_COMPAT.md) · [Azahar (3DS)](https://github.com/HamzaDevz/azahar/blob/odin3/ODIN3_COMPAT.md) · [Dolphin (GC/Wii)](https://github.com/HamzaDevz/dolphin/blob/odin3/ODIN3_COMPAT.md) · [Cemu (Wii U)](https://github.com/HamzaDevz/Cemu/blob/odin3/ODIN3_COMPAT.md) · [Vita3K (Vita)](https://github.com/HamzaDevz/Vita3K/blob/odin3/ODIN3_COMPAT.md) · [aPS3e (PS3)](https://github.com/HamzaDevz/aps3e/blob/odin3/ODIN3_COMPAT.md) · [Bachata S4 (PS4)](https://github.com/HamzaDevz/bachata-s4/blob/odin3/ODIN3_COMPAT.md) · [xemu (Xbox)](https://github.com/HamzaDevz/xemu/blob/odin3/ODIN3_COMPAT.md)

## Échelle

| Statut | Sens |
|---|---|
| 🟢 Parfait | vu en partie, plein régime, aucun défaut vu |
| 🔵 Jouable | vu en partie, défauts mineurs |
| 🟡 Problèmes | vu en partie, défauts gênants (fps, graphismes, son) |
| 🟠 Menus/intro | démarre, pas encore vu en partie |
| 🔴 Ne marche pas | crash, écran noir ou blocage |
| ⚪ Non testé | présent sur la console, jamais lancé |

## Comment on teste

Paquet `org.vita3k.emulator.odin3` (« Vita3K », dossier `/storage/FBDD-1F17/Emulations/vita3k`) ; le banc utilise `org.vita3k.emulator.odin3.debug`. `tools/odin3/run.sh` restaure une sauvegarde, joue un scénario d'entrées et mesure par segment fps (SurfaceFlinger), images lentes, puissance et températures ; une capture comparée à `refs/` signale un rendu cassé au-delà de 10 % d'écart. Config par jeu dans `config/config_<ID>.xml`, patchs 60 fps dans `patch/<ID>-60fps.txt` (sources dans `tools/odin3/patches/`).

Uncharted : accès direct aux 34 chapitres avec la [sauvegarde européenne Apollo](https://bucanero.github.io/apollo-saves/PSV/PCSF00001/), chargement vérifié sur PCSF00012. Banque locale : `tools/odin3/runs/codex-uncharted/save-all-chapters`, parcours automatisé `check-chapter.sh` dans le même dossier ; sauvegarde personnelle mise à l'abri pendant chaque série puis restaurée. Les captures scrcpy doivent utiliser `--audio-source=playback --audio-dup` pour conserver le son sur la console ; certaines prises Cubeb dupliquées sont muettes et ne prouvent donc pas la synchronisation audio.

## Jeux

| Jeu | Statut | Vu jusqu'à | Mesure | Notes | Testé le | Build |
|---|---|---|---|---|---|---|
| Gravity Rush (EU v1.00) `PCSF00024` | 🟢 Parfait | en jeu, faille de l'épisode 6 (~24 s) | 59,8 fps, 0,4 % d'images lentes, 3,7 W, CPU 61 °C | patch 60 fps requis (30 fps natifs) ; 7d30d659 corrige l'image blanche ; zone chargée par option de debug : à confirmer en progression normale | 2026-10-18 | 7d30d659 (banc) |
| Uncharted: Golden Abyss (v1.03) `PCSF00012` | 🔵 Jouable | prologue, escalade et tirs ; ouvertures des chapitres 1, 14 et 34 par sélection directe | x1 + fps-hack : 60,0 / 59,7 / 59,8 fps sur environ 15 s par chapitre, pire image 16,7 / 50 / 33 ms ; chapitre 1 en x2 : 35,3 fps après la cinématique | x1/60 + Cubeb retenus dans la release ; aucune nouvelle erreur Vulkan sur ces trois points ; son du prologue confirmé par Hamza ; synchro fine des autres cinématiques non certifiée par les prises Cubeb muettes ; couverture limitée à ces passages, saccades de chargement connues | 2026-10-19 | f3da152b |
| Soul Sacrifice Delta (v1.30) `PCSA00152` | 🟡 Problèmes | prologue, cage, premier combat | 59,5-59,7 fps en combat, 3,9-6,4 W | crash intermittent au début du premier combat (2 runs sur 3, lectures invalides en boucle, journal de plusieurs Go) ; patch 60 fps requis ; crash du compilateur de shaders corrigé (d9a2f586) | 2026-10-17 | avant 7d30d659 |
| Metal Slug 3 (EU 1.01) `PCSB00772` | 🟡 Problèmes | début de la mission 1 | 60 fps, 11,5 W, CPU 104 °C | rendu correct mais chauffe et consommation énormes pour un jeu 2D (2 threads FOCAL à 100 %) | 2026-10-17 | a3965763 (banc) |
| Ninja Gaiden Sigma Plus (USA) `PCSE00021` | 🔵 Jouable | nouvelle partie Normal, premier combat, déplacements et attaques, porte de l'autel ; revérifié sur la release installée | 30,0 fps à l'entrée en jeu, 738 images sur 24,6 s, pire 58 ms (release, Cubeb) ; 30,0 fps aussi avec validation Vulkan | crash au chargement de la partie corrigé : entrée fragment TexCoord1 sans sortie vertex correspondante ; sorties Vulkan manquantes définies à zéro, cache v15 ; plus d'erreur de liaison, 103 shaders validés ; fps-hack rejeté : animation accélérée ×1,955 sur 13 correspondances de la même séquence (captures `codex-ng60/animation30-fresh.mkv` et `animation60.mkv`, calcul `speed-verdict.json`) ; 30 fps natifs conservés, aucun patch 60 fps à vitesse normale validé ; suite du jeu non testée | 2026-10-19 | f3da152b |
| God of War Collection (EU) `PCSF00438` | 🟠 Menus/intro | lanceur, intro de GoW I | lanceur 60 fps, intro 30 fps | fonction NID 0xE87D1777 absente, fichiers `*_FR.tga` manquants ; GoW II pas testé | 2026-10-17 | a3965763 (banc) |
| Ratchet & Clank Trilogy (EU) `PCSF00482` | 🟠 Menus/intro | lanceur, menu de R&C 1 | menu 30 fps ; lanceur non limité (41-99 fps, 13-17 W, CPU 104 °C) | fonction NID 0xE87D1777 absente ; R&C 2 et 3 pas testés | 2026-10-17 | a3965763 (banc) |
| Final Fantasy X HD Remaster (USA) `PCSE00293` | 🟠 Menus/intro | cinématique d'intro | 27,7 fps (cible 30), pics à 214 ms | dump allégé : installation possible depuis 9d4751f8, 56 erreurs de fichiers absents (à refaire avec un dump complet) | 2026-10-17 | après 9d4751f8 |

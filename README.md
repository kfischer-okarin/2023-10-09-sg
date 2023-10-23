# Bloody Shapes

A [Small Game](https://abagames.github.io/joys-of-small-game-development-en/) made with
[DragonRuby GTK](https://dragonruby.itch.io/dragonruby-gtk) between Oct 9th and Oct 23rd, 2023.

[Itch.io Page](https://kfischer-okarin.itch.io/bloody-shapes)

## How to checkout the game
1. Extract the DragonRuby version you want to use somewhere
2. Delete original `mygame` folder (or alternatively rename it into `mygame-template` if you want to keep the files around)
3. Clone your game (this repository) via git
4. Copy the DragonRuby engine into your game repository (don't forget the hidden `.dragonruby` folder)

## How to update the DragonRuby version
1. Execute following command in your repository
   ```sh
   git clean -f -x -d
   ```
   This will recursively delete all unknown & ignored files in your repository (i.e. the engine).

   Be aware that this might also delete all other ignored files in your repository (like maybe save games) - so if you want
   to keep anything make sure that you backup those files first
2. Copy the new version of the DragonRuby engine into your game repository (don't forget the hidden `.dragonruby` folder)

## Credits
- `notalot.ttf` by Chequered Ink (https://www.dafont.com/notalot60.font)
- `shuriken.mp3` - 効果音ラボ - 戦闘(2) -  [手裏剣を投げる](https://soundeffect-lab.info/sound/battle/mp3/dart1.mp3)
- `charge1.mp3` - Springing' Sound Stack - 戦闘 - [気を溜める３](https://www.springin.org/wp-content/uploads/2022/06/%E6%B0%97%E3%82%92%E6%BA%9C%E3%82%81%E3%82%8B3.mp3)
- `charge2.mp3` - 効果音ラボ - 戦闘(1) - [ステータス上昇魔法２](https://soundeffect-lab.info/sound/battle/mp3/magic-statusup2.mp3)

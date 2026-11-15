# XbiGold

Gold making addon for **World of Warcraft: Forever**: auction house deals, what to farm, vendor flips,
profession profits, price charts and the best time to sell. Interface in French.

Addon de gold pour **WoW Forever** : bonnes affaires de l'HV, quoi farmer, reventes de marchand,
profits des métiers, courbes de prix et meilleur moment pour vendre.

- Download / Télécharger : https://www.curseforge.com/wow/addons (search "XbiGold")
- Changes / Nouveautés : [CHANGELOG.md](CHANGELOG.md)
- Licence : GPL-3.0 ([LICENSE](LICENSE)), credits : [CREDITS.md](CREDITS.md)

## Release / Sortir une version

```sh
./release.sh 1.3.2
```

The script checks that `CHANGELOG.md` starts with a `## 1.3.2` section, writes the version in
`XbiGold.toc`, commits, tags `v1.3.2` and pushes. GitHub Actions then builds the zip and uploads it
to CurseForge (secret `CF_API_KEY` in the repository settings).

Le script vérifie que `CHANGELOG.md` commence par une section `## 1.3.2`, met la version dans
`XbiGold.toc`, fait le commit, le tag `v1.3.2` et l'envoie. GitHub crée ensuite le zip et l'envoie
sur CurseForge.

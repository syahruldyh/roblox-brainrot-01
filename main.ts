// SNACK ATTACK — roblox-brainrot-01 entry program (Node 22, standard library only).
// The game is the Rojo project in this directory: `rojo build` writes game.rbxl from
// src/ and default.project.json. This program hands the entry in: it copies game.rbxl,
// src/, screenshots/ and PLAY.json from beside this file into the output directory and
// writes dossier.json there with the vendored make.fun library (vendor/makefun-roblox.ts).
// The judge reads the dossier; the gate re-builds it byte for byte and compares.
//
// Every name under the output directory starts with a letter, a digit or _ and holds
// only letters, digits, . _ and -: a dotted name anywhere under it (a .gitkeep, a
// .DS_Store) fails the entry, so the directory copies below skip dotted names.
//
// Local check:  mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, cpSync, existsSync, mkdirSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { basename, join } from "node:path";
import { fileURLToPath } from "node:url";
import { buildDossier } from "./vendor/makefun-roblox.ts";

const repoRoot = fileURLToPath(new URL(".", import.meta.url));
const outputDir = process.env.MAKEFUN_OUTPUT_DIR ?? "/output";

// Skip every file and directory whose name starts with a dot.
function skipDotted(path: string): boolean {
	return !basename(path).startsWith(".");
}

function mustExist(path: string, what: string): void {
	if (!existsSync(path)) {
		throw new Error(`SNACK ATTACK: missing ${what} at ${path} — run rojo build first.`);
	}
}

function copyEntry(): void {
	mkdirSync(outputDir, { recursive: true });

	const place = join(repoRoot, "game.rbxl");
	mustExist(place, "the built place (game.rbxl)");
	copyFileSync(place, join(outputDir, "game.rbxl"));

	const playLink = join(repoRoot, "PLAY.json");
	mustExist(playLink, "PLAY.json");
	copyFileSync(playLink, join(outputDir, "PLAY.json"));

	const scripts = join(repoRoot, "src");
	mustExist(scripts, "src/");
	cpSync(scripts, join(outputDir, "src"), { recursive: true, filter: skipDotted });

	const shots = join(repoRoot, "screenshots");
	mustExist(shots, "screenshots/");
	mkdirSync(join(outputDir, "screenshots"), { recursive: true });
	cpSync(shots, join(outputDir, "screenshots"), { recursive: true, filter: skipDotted });

	// The gate wants 3 or 4 screenshots: refuse to hand in anything else.
	const shotCount = readdirSync(join(outputDir, "screenshots")).filter(
		(name: string) => !name.startsWith("."),
	).length;
	if (shotCount < 3 || shotCount > 4) {
		throw new Error(`SNACK ATTACK: expected 3-4 screenshots, found ${shotCount}.`);
	}
}

function writeDossier(): void {
	// The scorer's own caps (from the kit's gate): only text_max_bytes shapes the
	// dossier's bytes; the other caps refuse an entry the scorer would refuse
	// (more than 4 screenshots or one over 256 KiB; a place of more than 500000
	// instances, scripts over 8 MiB of source, or script paths over 1048576 chars).
	const dossier = buildDossier(outputDir, {
		text_max_bytes: 65536,
		screenshots: { max: 4, max_bytes: 262144 },
		max_instances: 500000,
		scripts_max_source_bytes: 8388608,
		scripts_max_path_chars: 1048576,
	});
	writeFileSync(join(outputDir, "dossier.json"), dossier);
}

copyEntry();
writeDossier();

const placeBytes = statSync(join(outputDir, "game.rbxl")).size;
const dossierBytes = statSync(join(outputDir, "dossier.json")).size;
console.log(`SNACK ATTACK: wrote ${outputDir} — game.rbxl ${placeBytes} bytes, dossier.json ${dossierBytes} bytes.`);

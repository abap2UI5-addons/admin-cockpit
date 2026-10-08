// The description of a class or interface lives twice: <DESCRIPT> in the
// .xml and the "shorttext synchronized" ABAP Doc line in the source. The
// system takes it from the source, so a mismatch shows up in abapGit as a
// diff on the .xml after every pull - one that never goes away.
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

const failures = [];
let checked = 0;
for (const pkg of readdirSync("src")) {
  const dir = join("src", pkg);
  if (!statSync(dir).isDirectory()) {
    continue;
  }
  for (const file of readdirSync(dir)) {
    const match = file.match(/^(.+)\.(clas|intf)\.xml$/);
    if (!match) {
      continue;
    }
    const xml = readFileSync(join(dir, file), "utf8");
    const descript = xml.match(/<DESCRIPT>([^<]*)<\/DESCRIPT>/)?.[1] ?? "";
    const source = readFileSync(join(dir, `${match[1]}.${match[2]}.abap`), "utf8");
    const shorttext = source.match(/shorttext synchronized">([^<]*)</)?.[1];
    checked++;
    if (shorttext !== undefined && shorttext !== descript) {
      failures.push(`${dir}/${file}: <DESCRIPT> "${descript}" but the source says "${shorttext}"`);
    }
  }
}
for (const failure of failures) {
  console.error(failure);
}
console.log(`shorttext: ${checked} objects, ${failures.length} mismatch(es)`);
process.exit(failures.length ? 1 : 0);

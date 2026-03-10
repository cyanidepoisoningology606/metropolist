import type { Station, Transfer } from "./types";
import { parseCSV } from "./csv";
import { log, readFile } from "./helpers";

export async function buildTransfers(
  gtfsDir: string,
  stationById: Map<string, Station>,
  quaiToStation: Map<string, string>,
): Promise<Transfer[]> {
  log("Step 6: Building transfers...");

  const transfersRaw = parseCSV(await readFile(`${gtfsDir}/transfers.txt`));

  // Deduplicate: (stationA, stationB) → min transfer time
  const transferMap = new Map<string, number>();

  for (const row of transfersRaw) {
    const fromQuai = row.from_stop_id;
    const toQuai = row.to_stop_id;

    const fromStation =
      quaiToStation.get(fromQuai) ??
      (stationById.has(fromQuai) ? fromQuai : null);
    const toStation =
      quaiToStation.get(toQuai) ??
      (stationById.has(toQuai) ? toQuai : null);

    if (!fromStation || !toStation) continue;
    if (fromStation === toStation) continue;

    // Canonical key (sorted to avoid duplicating A→B and B→A)
    const [a, b] =
      fromStation < toStation
        ? [fromStation, toStation]
        : [toStation, fromStation];
    const key = `${a}|${b}`;
    const time = parseInt(row.min_transfer_time || "0") || 0;
    const existing = transferMap.get(key);

    if (existing === undefined || time < existing) {
      transferMap.set(key, time);
    }
  }

  const transfers: Transfer[] = [];
  for (const [key, time] of transferMap) {
    const [from, to] = key.split("|");
    transfers.push({
      fromStationId: from,
      toStationId: to,
      minTransferTime: time,
    });
  }
  log(`  → ${transfers.length} unique station-to-station transfers`);

  return transfers;
}

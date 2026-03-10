import type { Line, RawRefLine } from "./types";
import { parseCSV } from "./csv";
import { log, readFile, mapRefMode, mapGTFSRouteType } from "./helpers";

export function buildLineFromRef(lineId: string, ref: RawRefLine): Line {
  const shortName = ref.shortname_line || "";
  const submode = ref.transportsubmode || null;
  return {
    id: lineId,
    shortName,
    longName: ref.name_line || "",
    mode: mapRefMode(ref.transportmode, submode, shortName),
    submode,
    color: (ref.colourweb_hexa || "888888").toLowerCase(),
    textColor: (ref.textcolourweb_hexa || "000000").toLowerCase(),
    operatorName: ref.operatorname || "",
    networkName: ref.networkname || null,
    status: ref.status === "prochainement active" ? "upcoming" : "active",
    isAccessible: ref.accessibility === "true",
    groupId: ref.id_groupoflines || null,
    groupName: ref.shortname_groupoflines || null,
  };
}

export async function buildLines(
  gtfsDir: string,
  refByLineId: Map<string, RawRefLine>,
  replacementLineIds: Set<string>,
): Promise<{ lines: Line[]; lineIds: Set<string> }> {
  log("Step 2: Building lines...");

  const routesRaw = parseCSV(await readFile(`${gtfsDir}/routes.txt`));

  const lines: Line[] = [];
  const lineIds = new Set<string>();

  // Build lines from GTFS routes, enriching with referentiel data
  for (const route of routesRaw) {
    const routeId = route.route_id;
    if (replacementLineIds.has(routeId)) continue;
    const ref = refByLineId.get(routeId);

    if (ref) {
      const line = buildLineFromRef(routeId, ref);
      // Override with GTFS values where referentiel is empty
      line.shortName = ref.shortname_line || route.route_short_name || "";
      line.longName = ref.name_line || route.route_long_name || "";
      lines.push(line);
    } else {
      const shortName = route.route_short_name || "";
      const routeType = parseInt(route.route_type || "3") || 3;
      lines.push({
        id: routeId,
        shortName,
        longName: route.route_long_name || "",
        mode: mapGTFSRouteType(routeType, null, shortName),
        submode: null,
        color: (route.route_color || "888888").toLowerCase(),
        textColor: (route.route_text_color || "000000").toLowerCase(),
        operatorName: "",
        networkName: null,
        status: "active",
        isAccessible: false,
        groupId: null,
        groupName: null,
      });
    }
    lineIds.add(routeId);
  }

  // Add referentiel-only lines not in GTFS (upcoming lines with no trips)
  for (const [lineId, ref] of refByLineId) {
    if (!lineIds.has(lineId)) {
      lines.push(buildLineFromRef(lineId, ref));
      lineIds.add(lineId);
    }
  }

  log(`  → ${lines.length} lines built`);
  return { lines, lineIds };
}

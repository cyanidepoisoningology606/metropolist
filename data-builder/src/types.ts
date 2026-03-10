export type TransportMode =
  | "metro"
  | "rer"
  | "train"
  | "tram"
  | "bus"
  | "cableway"
  | "funicular"
  | "regionalRail"
  | "railShuttle";

export interface Line {
  id: string;
  shortName: string;
  longName: string;
  mode: TransportMode;
  submode: string | null;
  color: string;
  textColor: string;
  operatorName: string;
  networkName: string | null;
  status: "active" | "upcoming";
  isAccessible: boolean;
  groupId: string | null;
  groupName: string | null;
}

export interface Station {
  id: string;
  name: string;
  latitude: number;
  longitude: number;
  fareZone: string | null;
  town: string | null;
  postalCode: string | null;
  isAccessible: boolean;
  hasAudibleSignals: boolean;
  hasVisualSigns: boolean;
}

export interface RouteVariant {
  id: string;
  lineId: string;
  direction: number;
  headsign: string;
  stationCount: number;
}

export interface LineStop {
  lineId: string;
  stationId: string;
  routeVariantId: string;
  order: number;
  isTerminus: boolean;
}

export interface Transfer {
  fromStationId: string;
  toStationId: string;
  minTransferTime: number;
}

export interface OutputData {
  dataVersion: number;
  generatedAt: string;
  sourceFiles: Record<string, string>;
  lines: Line[];
  stations: Station[];
  lineStops: LineStop[];
  routeVariants: RouteVariant[];
  transfers: Transfer[];
}

/** Raw record from referentiel-des-lignes.json (IDFM open data) */
export interface RawRefLine {
  id_line: string;
  shortname_line: string;
  name_line: string;
  transportmode: string;
  transportsubmode: string;
  colourweb_hexa: string;
  textcolourweb_hexa: string;
  operatorname: string;
  networkname: string;
  status: string;
  accessibility: string;
  id_groupoflines: string;
  shortname_groupoflines: string;
  type: string;
}

/** Raw record from arrets.json (IDFM open data) */
export interface RawArret {
  arrid: string;
  arraccessibility: string;
  arraudiblesignals: string;
  arrvisualsigns: string;
  arrtown: string;
  arrpostalregion: string;
  arrfarezone: string;
}

/** Raw record from arrets-lignes.json (IDFM open data) */
export interface RawArretLigne {
  stop_id: string;
  stop_name: string;
  stop_lat: string;
  stop_lon: string;
  nom_commune: string;
  code_insee: string;
}

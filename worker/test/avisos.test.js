import { test } from "node:test";
import assert from "node:assert/strict";
import { avisosDelDia, hoyPanama, sumarDias, fechaLarga, TEMAS_VALIDOS } from "../src/push/avisos.js";

const SEM = ["2026-S1", "2026-S2", "2027-S1"];
const cal = [
  { categoria: "GRUPO 3", fecha_pago: "2026-10-30" },
  { categoria: "JUBILADOS", fecha_pago: "2027-01-02" },
  { categoria: "GRUPO 1", fecha_pago: "2026-12-04" },
];
const xiii = [{ fecha_aprox: "2026-12-04" }];
const temas = (h) => avisosDelDia(h, cal, xiii, SEM).map((a) => a.tema).sort();

test("el mismo día, un día antes y tres días antes", () => {
  assert.deepEqual(temas("2026-10-30"), ["grupo3-d0"]);
  assert.deepEqual(temas("2026-10-29"), ["grupo3-d1"]);
  assert.deepEqual(temas("2026-10-27"), ["grupo3-d3"]);
  assert.deepEqual(temas("2026-10-28"), []);
});

test("texto con fecha en español y coletilla no oficial", () => {
  const [a] = avisosDelDia("2026-10-29", cal, xiii, SEM);
  assert.equal(a.titulo, "Mañana te pagan 💸");
  assert.equal(a.cuerpo, "Grupo 3 · viernes 30 de octubre · fecha referencial (fuente: MEF)");
});

test("cambio de año: aviso d3 de la quincena de enero sale el 30 de diciembre", () => {
  assert.deepEqual(temas("2026-12-30"), ["jubilados-d3"]);
});

test("décimo llega a todas las categorías; si coincide con quincena, un solo aviso", () => {
  const av = avisosDelDia("2026-12-03", cal, xiii, SEM);
  assert.equal(av.length, 5);
  const g1 = av.find((a) => a.tema === "grupo1-d1");
  assert.match(g1.titulo, /quincena y se espera tu décimo/);
  const g2 = av.find((a) => a.tema === "grupo2-d1");
  assert.equal(g2.titulo, "Se espera tu décimo mañana 💰");
  assert.match(g2.cuerpo, /fecha aproximada/);
  assert.equal(new Set(av.map((a) => a.tema)).size, av.length);
});

test("semestre no publicado: no se avisa nada", () => {
  assert.deepEqual(avisosDelDia("2026-10-29", cal, xiii, ["2026-S1"]), []);
});

test("hora del cron: 12:00 UTC es 7:00 AM del mismo día en Panamá; 03:00 UTC aún es el día anterior", () => {
  assert.equal(hoyPanama(new Date("2026-10-29T12:00:00Z")), "2026-10-29");
  assert.equal(hoyPanama(new Date("2026-10-30T03:00:00Z")), "2026-10-29");
});

test("utilidades de fecha y temas", () => {
  assert.equal(sumarDias("2026-02-27", 3), "2026-03-02");
  assert.equal(fechaLarga("2027-01-02"), "sábado 2 de enero");
  assert.equal(TEMAS_VALIDOS.size, 15);
  assert.ok(TEMAS_VALIDOS.has("gastosrep-d3"));
});

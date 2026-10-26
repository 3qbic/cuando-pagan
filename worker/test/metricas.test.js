import { test } from "node:test";
import assert from "node:assert/strict";
import { dimensionesApertura, registrar } from "../src/metricas.js";

const dim = (q) => dimensionesApertura(new URL("https://x/v1/version" + q));

test("dimensiones validas", () => {
  assert.deepEqual(dim("?p=web&v=0.5.0&d=1&push=1"),
    { plataforma: "web", version: "0.5.0", push: "1", dataVersion: 1 });
});

test("sin query -> desconocido", () => {
  assert.deepEqual(dim(""),
    { plataforma: "desconocido", version: "desconocido", push: "0", dataVersion: 0 });
});

test("la app sin versión legible manda v=desconocido -> desconocido", () => {
  assert.equal(dim("?p=web&v=desconocido&d=1&push=0").version, "desconocido");
});

test("valores invalidos -> otro / 0", () => {
  assert.deepEqual(dim("?p=xbox&v=<script>&d=-5&push=si"),
    { plataforma: "otro", version: "otro", push: "0", dataVersion: 0 });
  assert.equal(dim("?d=99999").dataVersion, 0);
  assert.equal(dim("?v=1.2.3.4").version, "otro");
});

test("registrar escribe el data point", () => {
  const llamadas = [];
  registrar({ USO: { writeDataPoint: (x) => llamadas.push(x) } }, "apertura", ["web", "0.5.0", "1"], [1]);
  assert.equal(llamadas.length, 1);
  assert.deepEqual(llamadas[0],
    { indexes: ["apertura"], blobs: ["apertura", "web", "0.5.0", "1"], doubles: [1] });
});

test("registrar nunca lanza", () => {
  assert.doesNotThrow(() => registrar({}, "apertura", ["a"], [1]));
  assert.doesNotThrow(() => registrar(undefined, "apertura", ["a"], [1]));
  assert.doesNotThrow(() => registrar({ USO: { writeDataPoint() { throw new Error("x"); } } }, "apertura", ["a"], [1]));
});

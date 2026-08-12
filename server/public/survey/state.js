(function (global) {
  "use strict";

  const CAMPAIGN = "2026-08-v1";
  const KINDS = ["misconception", "type"];
  const memory = Object.create(null);

  function key(kind, field) {
    if (!KINDS.includes(kind))
      throw new TypeError("Unknown survey kind: " + kind);
    return `dekisugi:survey:${CAMPAIGN}:${kind}:${field}`;
  }

  const KEYS = KINDS.flatMap((kind) => [
    key(kind, "session"),
    key(kind, "complete"),
  ]);

  function storedValue(area, storageKey) {
    try {
      return global[area].getItem(storageKey);
    } catch (e) {
      return null;
    }
  }

  function read(storageKey) {
    const localValue = storedValue("localStorage", storageKey);
    if (localValue !== null) return localValue;
    const sessionValue = storedValue("sessionStorage", storageKey);
    if (sessionValue !== null) return sessionValue;
    return Object.prototype.hasOwnProperty.call(memory, storageKey)
      ? memory[storageKey]
      : null;
  }

  function write(storageKey, value) {
    try {
      global.localStorage.setItem(storageKey, value);
      delete memory[storageKey];
      // 以前のfallback値が残ってlocalStorageと食い違わないようにする。
      try {
        global.sessionStorage.removeItem(storageKey);
      } catch (e) {
        /* localStorageを使用中 */
      }
      return;
    } catch (e) {
      // Safari のプライベートブラウズなどでは、同じタブで共有される領域へ退避する。
    }
    try {
      global.sessionStorage.setItem(storageKey, value);
      delete memory[storageKey];
      return;
    } catch (e) {
      // sessionStorageも使えない場合だけ、このdocument内のメモリへ退避する。
    }
    memory[storageKey] = value;
  }

  function remove(storageKey) {
    delete memory[storageKey];
    try {
      global.localStorage.removeItem(storageKey);
    } catch (e) {
      /* fallback側も消す */
    }
    try {
      global.sessionStorage.removeItem(storageKey);
    } catch (e) {
      /* memory側は消去済み */
    }
  }

  function isUuid(value) {
    return (
      typeof value === "string" &&
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
        value,
      )
    );
  }

  function newUuid() {
    if (global.crypto && typeof global.crypto.randomUUID === "function") {
      return global.crypto.randomUUID();
    }
    const bytes = new Uint8Array(16);
    if (global.crypto && typeof global.crypto.getRandomValues === "function") {
      global.crypto.getRandomValues(bytes);
    } else {
      for (let i = 0; i < bytes.length; i++)
        bytes[i] = Math.floor(Math.random() * 256);
    }
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    const hex = [...bytes]
      .map((value) => value.toString(16).padStart(2, "0"))
      .join("");
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
  }

  function getSessionId(kind) {
    const storageKey = key(kind, "session");
    const saved = read(storageKey);
    if (isUuid(saved)) return saved;
    if (saved !== null) remove(storageKey);
    const created = newUuid();
    write(storageKey, created);
    return created;
  }

  function isComplete(kind) {
    return read(key(kind, "complete")) === "1";
  }

  function markComplete(kind) {
    write(key(kind, "complete"), "1");
  }

  function resetCampaign() {
    KEYS.forEach(remove);
  }

  function otherKind(kind) {
    if (!KINDS.includes(kind))
      throw new TypeError("Unknown survey kind: " + kind);
    return kind === "misconception" ? "type" : "misconception";
  }

  global.SurveyState = Object.freeze({
    campaign: CAMPAIGN,
    getSessionId,
    isComplete,
    markComplete,
    resetCampaign,
    otherKind,
  });
})(window);

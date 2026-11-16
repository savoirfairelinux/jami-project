# Offline Mesh Messaging — Architecture & Roadmap

Status: partly implemented in `tucnet-android/` (version 0.2).

| Part | State |
|---|---|
| On-device identity, QR contact cards | Built (`core/Identity.kt`) |
| X3DH + Double Ratchet + AES-256-GCM, 1:1 text | Built, unit-tested (`core/Session.kt`) |
| Flooding router, hop limit, dedup, 24 h store-and-forward, delivery receipts | Built, unit-tested (`core/Engine.kt`) |
| BLE bearer (advertise, scan, GATT link), foreground service | Built, **not yet tested on real phones** (`app/BleBearer.kt`) |
| Wi-Fi Aware, files, rooms, Meshtastic, on-device AI, APK sharing, iOS | Not started |

Differences from the plan below, for the code that exists today:

- The mesh core is a pure Kotlin/JVM module (`tucnet-android/core`), not C++. It has no Android
  dependencies, so it runs under plain JVM unit tests. Porting to C++ is only needed for iOS.
- Delivery receipts are not signatures. The message id is the hash of a secret carried inside the
  ciphertext; the recipient reveals the secret, and any carrier can check it and drop its copy.
- The routing header is 34 bytes and has no fragment fields; the BLE link layer does the chunking.
- Each payload carries an 8-byte session tag so the recipient can find the right ratchet. A relay can
  therefore tell that two packets belong to the same conversation, though not whose it is.
- Not implemented yet: per-hop Noise encryption, signed-prekey rotation, one-time prekeys,
  anti-entropy summaries (a new link simply receives everything the carrier holds), rate limits.

This repository is a fork of `jami-project`: a C++ daemon (`daemon/`, libjami),
a Kotlin Android client (`client-android/`), a Swift iOS client (`client-ios/`)
and a Qt desktop client. The plan below adds an offline mesh bearer next to
Jami's existing internet path (OpenDHT + ICE + TLS) instead of replacing it.

Target order: **Android first** (the only platform where every feature is
possible), iOS second with a reduced feature set.

## 1. What Jami already gives us

| Requirement | Jami today | Gap |
|---|---|---|
| Zero-account identity | Yes. On-device key pair + X.509 chain, no phone/e-mail | Mesh needs compact Curve25519 keys (RSA certs are too big for BLE/LoRa) |
| E2EE | Yes, TLS 1.3 with PFS between online devices | Needs both peers online and IP-reachable. No asynchronous first message |
| Offline delivery | Swarm conversations sync when peers meet on IP | No BLE / Wi-Fi Aware / LoRa bearers, no relaying through strangers |
| File transfer | Yes, over IP | No router-less high-speed link |

So the new work is: radio bearers, a relay/store-and-forward layer, an
asynchronous E2EE session layer, LoRa bridge, on-device AI and APK sharing.

## 2. Layered architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│ UI            Kotlin (Android) · Swift (iOS)                         │
│               Nearby · Chats · Rooms · Radar · Vault · Share app     │
├──────────────────────────────────────────────────────────────────────┤
│ App services  Chat · Rooms · File transfer · AI pipeline · App share │
├──────────────────────────────────────────────────────────────────────┤
│ Session/E2EE  Identity · X3DH · Double Ratchet · Sender Keys (rooms) │
├──────────────────────────────────────────────────────────────────────┤
│ Mesh core     Packet codec · Router · Dedup · DTN store · Fragmenter │
│ (libmesh,     Bearer selector · ACK/receipt handling                 │
│  portable C++)                                                       │
├──────────────────────────────────────────────────────────────────────┤
│ Bearers       BLE │ Wi-Fi Aware │ Wi-Fi Direct │ Meshtastic │ Jami   │
│ (platform)    GATT/L2CAP  NDP sockets  fallback    LoRa       DHT/IP │
└──────────────────────────────────────────────────────────────────────┘
```

Design decisions:

- **Mesh core is portable C++ (`libmesh`) built with the daemon** and exposed
  through the JNI/Swift bridge Jami already uses. Packet format, routing,
  the store and the crypto must be bit-identical on Android and iOS; writing
  them once avoids a rewrite when iOS starts.
- **Bearers are platform code** (Kotlin / Swift) behind one interface:
  `discover()`, `connect(peer)`, `send(frame)`, `onFrame`, `mtu`, `costClass`.
- **Bearer selection per message**: direct BLE → direct Wi-Fi Aware → mesh
  relay → LoRa (text only) → Jami DHT when internet exists. Small messages go
  over whatever link is already up; payloads over ~64 KB trigger a Wi-Fi Aware
  upgrade negotiated over BLE.
- **Mesh identity is cross-signed by the Jami account** so one contact is one
  identity on both paths.

## 3. Wire format

Relays see only the routing header. Everything else is ciphertext.

```
Routing header (cleartext to relays, ~46 bytes)
  ver(1) type(1) flags(1) ttl_hops(1)
  msg_id(16)            random, used for dedup and ACKs
  recipient_hint(8)     HMAC(recipient identity key, day epoch)[0..8], rotates daily
  expires_at(4)         unix seconds, max now + 24 h
  frag_index(2) frag_count(2)
  payload_len(2)
Payload
  ratchet header (DH pub 32, pn 4, n 4) + AES-256-GCM ciphertext + tag 16
```

Notes:

- No sender field in the header. The sender is inside the ciphertext.
- Each hop is additionally wrapped in a Noise `XX` link session so a passive
  sniffer cannot read routing headers; only actual mesh neighbours can.
- A LoRa variant drops fragmenting and compresses the header to fit one
  Meshtastic packet (≈ 200 usable bytes after headers).

## 4. Modules

### 4.1 Dual-radio mesh (BLE + Wi-Fi Aware)

**BLE — discovery, handshake, small messages**

- Advertise one 128-bit service UUID plus 8 bytes of service data
  (own rotating hint). Scan with a `ScanFilter` on that UUID.
- Transport: L2CAP CoC (Android 10+, iOS 11+) when both sides support it,
  otherwise GATT write/notify with a negotiated MTU (up to 517).
- Realistic throughput: 20–100 kB/s. Good for text, receipts, prekey bundles,
  thumbnails. Not for media.
- Android: `BluetoothLeScanner`, `BluetoothLeAdvertiser`, `BluetoothGattServer`,
  `BluetoothDevice.createInsecureL2capChannel`. Helper libraries: Nordic
  `Android-BLE-Library` and `Android-Scanner-Compat-Library`.
- iOS: CoreBluetooth (`CBPeripheralManager`, `CBCentralManager`,
  `CBL2CAPChannel`) with state restoration.

**Wi-Fi Aware — bulk data**

- Android 8+: `WifiAwareManager` → publish/subscribe → `WifiAwareNetworkSpecifier`
  → `ConnectivityManager.requestNetwork` → plain TCP/QUIC sockets over IPv6
  link-local. Tens of Mbit/s.
- The Aware data path is secured with a passphrase derived from the Noise link
  session already established over BLE.
- iOS: the `WiFiAware` framework (iOS 26+, recent iPhones) requires a
  user-visible pairing step; before iOS 26 there is no interoperable
  high-speed link to Android — BLE only.
- **Fallback**: Wi-Fi Direct (`WifiP2pManager`) on Android devices without
  Aware. Check `PackageManager.FEATURE_WIFI_AWARE` at runtime; many budget
  phones do not have it.

**Routing (multi-hop)**

1. *MVP — managed flooding*: every node re-broadcasts unseen packets to all
   neighbours, decrementing `ttl_hops` (start 7). Dedup with an LRU of
   `msg_id`s plus a Bloom filter. Random 0–500 ms forwarding jitter.
2. *Next — epidemic with anti-entropy*: on each encounter, exchange a Bloom
   summary of held `msg_id`s and send only what the other side lacks.
3. *Later — PRoPHET or Spray-and-Wait*: use encounter history to stop
   copying to nodes unlikely to meet the recipient. Do this only once real
   usage data shows flooding is too expensive.

**Large files**

- 256 KB chunks, SHA-256 per chunk, manifest (chunk hashes, name, size, mime)
  sent as a normal encrypted message. Resumable by chunk index.
- Direct Wi-Fi Aware link: no size limit.
- Multi-hop relay: capped (suggest 5 MB) and opt-in on carriers, otherwise
  one video drains every relay's quota.

### 4.2 Delay-tolerant store-and-forward

- Store: SQLite table in `libmesh` keyed by `msg_id`, indexed by
  `recipient_hint` and `expires_at`. Only ciphertext + routing header.
- Limits: 24 h TTL (sender sets, relays clamp), 50 MB total quota,
  per-neighbour rate limit, evict expired → largest → oldest.
- Delivery trigger: a peer's BLE advert carries its own current hint. A carrier
  that holds packets for that hint connects and delivers. Summary-vector
  exchange on every encounter covers recipients more than one hop away.
- ACKs: the recipient emits a signed delivery receipt (`msg_id`), flooded with
  a short TTL; carriers that see it delete their copy.
- Abuse control: per-identity rate limits, proof-of-work stamp on packets from
  non-contacts, and a hard quota. Relays cannot inspect content, so limits are
  the only defence against flooding.

### 4.3 Meshtastic LoRa bridge

- Phone ↔ radio over BLE GATT (Meshtastic service: `ToRadio`, `FromRadio`,
  `FromNum` characteristics) or USB serial (`usb-serial-for-android`; stream
  framing `0x94 0xC3 len_hi len_lo`). iOS: BLE only.
- Messages are protobufs from `meshtastic/protobufs`
  (`ToRadio`, `FromRadio`, `MeshPacket`, `Data`). Generate Kotlin/Swift/C++
  from the `.proto` files; do not copy app code.
- Send our packets as `PortNum.PRIVATE_APP` binary payloads so that our own
  E2EE is preserved end to end. Also support plain `TEXT_MESSAGE_APP` for
  talking to stock Meshtastic users (marked clearly as not using our E2EE).
- Constraints: ≈ 200 bytes per packet, very low bitrate, regional duty-cycle
  and frequency rules (set the region on the radio, e.g. `PH_915`). Text only;
  no fragmentation of media over LoRa. Rate-limit to a few messages per minute.
- A phone with a radio attached acts as a gateway: it bridges packets between
  the BLE/Wi-Fi mesh and LoRa for small text packets only.

### 4.4 Serverless E2EE and identity

- **Identity**: Ed25519 signing key + X25519 identity key generated on device,
  private keys wrapped by Android Keystore / iOS Keychain (Secure Enclave
  wrapping key). User ID = fingerprint of the identity key. Signed by the Jami
  account certificate. Contact verification by QR code or safety number.
- **X3DH without a server**: a prekey bundle (identity key, signed prekey,
  signature) is distributed three ways: QR code in person, BLE handshake on
  first direct contact, and signed "identity announcements" gossiped and cached
  by the mesh. One-time prekeys are included only in QR/direct exchanges; a
  gossiped bundle cannot hand out single-use keys safely. Per the X3DH spec,
  first messages without a one-time prekey can be replayed, so the recipient
  dedups on `msg_id` and ratchets immediately.
- **Forward secrecy**: Double Ratchet after X3DH (new message key per message,
  DH ratchet on every reply). Signed prekey rotates weekly. Skipped-message
  keys are kept (up to 1000 / 7 days) because DTN delivery is heavily
  out-of-order.
- **AEAD**: AES-256-GCM with a fresh key per message from the ratchet.
- **Rooms**: Sender Keys (one symmetric chain per sender, distributed over the
  pairwise sessions), re-keyed when a member leaves.
- **Libraries**: libsodium (X25519, Ed25519, HKDF, hashing) in `libmesh`.
  AES-256-GCM from nettle/GnuTLS, which the daemon already links — libsodium's
  AES-GCM needs hardware AES and is absent on some low-end chips. `libsignal`
  is an alternative for X3DH + Double Ratchet but is AGPL-3.0 and assumes a
  server for prekeys. Noise link layer: `noise-c`.
- Whatever is chosen, **use an existing reviewed implementation of the ratchet
  and budget an external audit before public release**.

### 4.5 On-device AI

All inference runs after decryption on the recipient's device. Relays can
never moderate E2EE content.

| Task | Android | iOS | Model size |
|---|---|---|---|
| Speech-to-text | whisper.cpp or sherpa-onnx; Vosk for small models | Speech framework (on-device mode), or whisper.cpp via Core ML | 40–150 MB |
| Translation | ML Kit Translation (needs Play Services; packs downloaded once), or CTranslate2 + NLLB-200 distilled / Bergamot models for a Google-free build | Apple Translation framework, or the same CTranslate2 models | 30 MB per ML Kit language; 300–600 MB NLLB |
| Text moderation | MediaPipe Text Classifier / LiteRT with a small multilingual model | Core ML | 5–30 MB |
| Image moderation | LiteRT NSFW classifier | Core ML / Sensitive Content Analysis | 5–20 MB |

- Models are optional downloads, not bundled in the APK. Because users may
  never have internet, **model packs are shareable over the mesh** as signed
  files (same chunked transfer as media), verified against a hash list shipped
  in the app.
- Run inference in a background worker, only when charging or on user request
  for long audio. Low-RAM devices (≤ 3 GB) get the smallest tier or none.
- Moderation is a local filter/blur with user override, never a report to
  anyone.

### 4.6 Offline app sharing (Android only)

The receiver does not have the app yet, so the path cannot depend on our
protocol:

1. Sender starts `WifiManager.startLocalOnlyHotspot` (or a Wi-Fi Direct group)
   and an embedded HTTP server (Ktor/NanoHTTPD) serving the APK.
2. Sender shows two QR codes: Wi-Fi join, then `http://<ip>:<port>/`.
3. Receiver downloads in the browser and installs (must allow "install unknown
   apps").
4. Alternative: `ACTION_SEND` of the APK via `FileProvider` to Quick Share or
   Bluetooth.

- APK source: `applicationInfo.sourceDir` plus `splitSourceDirs`. Play Store
  installs are split; a browser cannot install splits. **Ship a universal APK
  for sideload/F-Droid builds**, or bundle the universal APK as an asset
  fetched once.
- Receiver-to-receiver updates between existing users can use
  `PackageInstaller` sessions with splits.
- The landing page shows the signing-certificate fingerprint; the app verifies
  its own signature on first run.
- iOS has no sideloading path. Share a store link only.

## 5. Message flow (1:1 text, recipient out of range)

1. Alice writes to Carlo. Session layer encrypts with the ratchet → payload.
2. Mesh core builds the header (`msg_id`, Carlo's hint, TTL 7, expiry +24 h).
3. Bearer selector: Carlo is not a neighbour → hand to router.
4. Router sends to all current neighbours over existing BLE links and stores a
   copy.
5. Ben's phone (a stranger) receives, dedups, stores ciphertext, forwards.
6. Hours later Ben's scanner sees an advert carrying Carlo's hint → connects →
   delivers.
7. Carlo decrypts, emits a signed delivery receipt.
8. The receipt floods back; Ben and other carriers delete their copies; Alice's
   UI shows "Delivered".

## 6. Platform limits and mitigations

| Limit | Effect | Mitigation |
|---|---|---|
| Android background execution (Doze, OEM battery killers on Xiaomi/Oppo/Vivo/Huawei) | Mesh stops when the app is swiped away | Foreground service (`connectedDevice` type) with persistent notification; `PendingIntent` BLE scans; onboarding step for battery-optimisation exemption; duty-cycled scanning |
| Android permissions | Android 12+: `BLUETOOTH_SCAN/ADVERTISE/CONNECT`; Android 13+: `NEARBY_WIFI_DEVICES`; older: location permission and location switched on | Staged permission onboarding with a plain explanation per permission |
| Wi-Fi Aware availability | Missing on many low-end phones; unavailable while hotspot / Wi-Fi Direct is active on some chipsets; limited concurrent data paths (often 1–2) | Runtime feature check, Wi-Fi Direct fallback, one bulk transfer at a time, tear down the data path when idle |
| iOS background BLE | Advertised UUID moves to the overflow area, scans are slow and coalesced, app can be suspended | State restoration, long-lived connections once found; state plainly in the UI that iPhones relay well only while the app is open |
| iOS ↔ Android high-speed link | None before iOS 26; pairing prompt after | BLE for cross-platform; Wi-Fi Aware where both sides support it |
| BLE connection count | ~4–7 concurrent links per phone | Connect briefly, sync, disconnect; prefer neighbours with new data |
| Battery | Continuous scan + advertise drains noticeably | Low-power scan mode by default, burst mode when the app is open, user-visible "relay mode" switch |
| Storage | Relay cache grows | 50 MB quota, 24 h TTL, eviction |
| Sideloading | Play Protect warnings; Google is introducing developer verification for sideloaded apps | Register the signing identity; keep an F-Droid build |
| LoRa regulation | Frequency and duty-cycle rules differ per country | Use the radio's region setting; do not let the app override it |
| Licensing | Jami is GPL-3.0, Meshtastic GPL-3.0, libsignal AGPL-3.0 | App stays GPL-3.0-compatible; avoid Play-Services-only dependencies in the F-Droid flavour |

Privacy limits to state openly: BLE presence is observable by anyone nearby,
recipient hints let someone who already knows a public key recognise that
packets are addressed to it, and traffic analysis by a relay that sits next to
the sender is possible.

## 7. Roadmap

Durations assume 2–3 developers and are rough estimates.

| Phase | Scope | Exit test |
|---|---|---|
| 0 — Spike (2 wks) | Init submodules, build Android client, test-device matrix (which phones have Wi-Fi Aware, L2CAP), new UI theme tokens | Two phones exchange bytes over BLE and over Aware in throwaway apps |
| 1 — MVP (6–8 wks) | `libmesh` skeleton, identity, QR contact add, BLE discovery + link, 1:1 text with X3DH + Double Ratchet, new Nearby and Chat screens | Two phones in airplane mode chat with E2EE |
| 2 — Mesh + DTN (6 wks) | Flooding router, dedup, 24 h store, receipts, foreground service, battery tuning | A → B → C relay works; message survives a 6 h gap and is delivered when C appears |
| 3 — High-speed (6 wks) | Wi-Fi Aware upgrade, chunked files, images, voice notes, Wi-Fi Direct fallback | 100 MB file transfers directly and resumes after interruption |
| 4 — Reach (4–6 wks) | APK sharing, Meshtastic bridge (BLE then USB) | Fresh phone installs from a peer offline; text crosses 1 km+ through two radios |
| 5 — AI (6 wks) | Transcription, translation, local moderation, model-pack sharing | Voice note is transcribed and translated in airplane mode on a mid-range phone |
| 6 — Scale | Rooms with Sender Keys, anti-entropy routing, iOS client, security audit, Jami Swarm sync over the mesh | Audit findings closed; 20-device field test |

## 8. Open decisions

- App name and branding ("Tucnet" used as a working name).
- Whether the Play Store flavour may depend on Play Services (ML Kit) or the
  app should be Google-free throughout.
- Relay default: on for everyone (stronger mesh, more battery) or opt-in.

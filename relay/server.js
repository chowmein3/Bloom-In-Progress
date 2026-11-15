// Bloom In Progress relay.
//
// Both players' games connect OUT to this server, so nobody needs to open a
// router port or know an IP address. A host opens a "room" named by its
// garden's invite code; a guest who knows the code joins it; after that the
// server just passes game messages between the two.
//
// It stores nothing: no accounts, no gardens, no logs of what is played.
//
// Messages (JSON text frames) from a game:
//   {"t":"host","code":"ABCDEF","name":"Willow Bend"}  -> {"t":"hosting"}
//   {"t":"join","code":"ABCDEF"}                       -> {"t":"joined","name":...}
//   {"t":"find","codes":["ABCDEF", ...]}               -> {"t":"found","rooms":[{code,name,full}]}
// To a game:  {"t":"peer_joined"}, {"t":"peer_left"}, {"t":"error","reason":...}
// Binary frames are forwarded untouched to the other player in the room.

const http = require("http");
const { WebSocketServer } = require("ws");

const PORT = process.env.PORT || 8787;
const MAX_ROOMS = 500;
const MAX_MESSAGE_BYTES = 256 * 1024;
const CODE = /^[A-Z0-9]{6}$/;

const rooms = new Map(); // code -> { name, host, guest }

const server = http.createServer((req, res) => {
  // Health check, and something friendly to see in a browser.
  res.writeHead(200, { "Content-Type": "text/plain" });
  res.end(`Bloom In Progress relay is running. Open gardens: ${rooms.size}\n`);
});

const wss = new WebSocketServer({ server, maxPayload: MAX_MESSAGE_BYTES });

function send(socket, message) {
  if (socket && socket.readyState === socket.OPEN) socket.send(JSON.stringify(message));
}

function leave(socket) {
  const code = socket.roomCode;
  const room = code && rooms.get(code);
  socket.roomCode = null;
  if (!room) return;
  if (room.host === socket) {
    // The garden lives on the host's computer, so the room ends with them.
    rooms.delete(code);
    if (room.guest) {
      room.guest.roomCode = null;
      send(room.guest, { t: "peer_left" });
      room.guest.close(1000, "host left");
    }
  } else if (room.guest === socket) {
    room.guest = null;
    send(room.host, { t: "peer_left" });
  }
}

function handle(socket, message) {
  if (message.t === "find") {
    const codes = Array.isArray(message.codes) ? message.codes.slice(0, 20) : [];
    const found = [];
    for (const code of codes) {
      const room = typeof code === "string" && rooms.get(code);
      if (room) found.push({ code, name: room.name, full: !!room.guest });
    }
    return send(socket, { t: "found", rooms: found });
  }
  if (typeof message.code !== "string" || !CODE.test(message.code)) {
    return send(socket, { t: "error", reason: "bad_code" });
  }
  if (socket.roomCode) return send(socket, { t: "error", reason: "busy" });

  if (message.t === "host") {
    const existing = rooms.get(message.code);
    if (existing && existing.host.readyState === existing.host.OPEN) {
      return send(socket, { t: "error", reason: "already_hosted" });
    }
    if (rooms.size >= MAX_ROOMS) return send(socket, { t: "error", reason: "server_full" });
    const name = String(message.name || "Garden").slice(0, 24);
    rooms.set(message.code, { name, host: socket, guest: null });
    socket.roomCode = message.code;
    return send(socket, { t: "hosting" });
  }
  if (message.t === "join") {
    const room = rooms.get(message.code);
    if (!room) return send(socket, { t: "error", reason: "not_open" });
    if (room.guest) return send(socket, { t: "error", reason: "full" });
    room.guest = socket;
    socket.roomCode = message.code;
    send(socket, { t: "joined", name: room.name });
    return send(room.host, { t: "peer_joined" });
  }
  send(socket, { t: "error", reason: "unknown" });
}

wss.on("connection", (socket) => {
  socket.roomCode = null;
  socket.alive = true;
  socket.on("pong", () => { socket.alive = true; });
  socket.on("message", (data, isBinary) => {
    if (isBinary) {
      const room = socket.roomCode && rooms.get(socket.roomCode);
      if (!room) return;
      const other = room.host === socket ? room.guest : room.host;
      if (other && other.readyState === other.OPEN) other.send(data, { binary: true });
      return;
    }
    let message;
    try { message = JSON.parse(data.toString()); } catch { return; }
    if (message && typeof message === "object") handle(socket, message);
  });
  socket.on("close", () => leave(socket));
  socket.on("error", () => leave(socket));
});

// Keep connections alive through proxies, and drop ones that have gone silent.
setInterval(() => {
  for (const socket of wss.clients) {
    if (!socket.alive) { socket.terminate(); continue; }
    socket.alive = false;
    socket.ping();
  }
}, 25000);

server.listen(PORT, () => console.log(`relay listening on ${PORT}`));

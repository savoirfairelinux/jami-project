package org.tucnet.app

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.cos
import kotlin.math.sin

private val W = Color.White
private fun glass(a: Float = 0.2f) = W.copy(alpha = a)

@Composable
private fun RoundBtn(ic: ImageVector, bg: Color, tint: Color = W, onClick: () -> Unit = {}) {
    Box(Modifier.size(40.dp).clip(CircleShape).background(bg).clickable(onClick = onClick), Alignment.Center) {
        Icon(ic, null, Modifier.size(20.dp), tint = tint)
    }
}

@Composable
private fun Title(text: String, color: Color = C.Ink) =
    Text(text, color = color, fontSize = 26.sp, fontWeight = FontWeight.ExtraBold)

// ---------------------------------------------------------------- Nearby

private data class Feed(
    val title: String, val sub: String, val tag: String, val hop: String,
    val a: Color, val b: Color, val ic: ImageVector, val dest: String,
)

private val feed = listOf(
    Feed("Barangay Relief", "Water point moved to gym", "Room · 9 online", "1 hop", Color(0xFF5A3DF0), Color(0xFF22B8FF), Ic.Mesh, "room"),
    Feed("Liza M.", "Sending map · 21 MB/s", "Wi-Fi Aware", "direct", Color(0xFFFF9A62), C.Pink, Ic.File, "chat"),
    Feed("Ridge Camp", "Text only · SNR 7.5 dB", "LoRa", "4.2 km", Color(0xFF0C8F6C), C.Blue, Ic.Tower, "room"),
    Feed("Carlo D.", "3 carriers have your message", "Held 3 h", "waiting", C.Violet, Color(0xFFD946EF), Ic.Shield, "chat"),
)

@Composable
private fun RowScope.Tile(label: String, a: Color, b: Color, ic: ImageVector, onClick: () -> Unit) {
    Box(
        Modifier.weight(1f).height(104.dp).clip(RoundedCornerShape(20.dp))
            .background(Brush.linearGradient(listOf(a, b))).clickable(onClick = onClick).padding(12.dp)
    ) {
        Text(label, color = W, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, lineHeight = 17.sp)
        Icon(ic, null, Modifier.size(36.dp).align(Alignment.BottomEnd), tint = W)
    }
}

@Composable
private fun RowScope.FeedCard(f: Feed, open: (String) -> Unit) {
    Column(Modifier.weight(1f).clip(RoundedCornerShape(18.dp)).background(W).clickable { open(f.dest) }) {
        Box(Modifier.fillMaxWidth().height(108.dp).background(Brush.linearGradient(listOf(f.a, f.b)))) {
            Icon(f.ic, null, Modifier.size(42.dp).align(Alignment.Center), tint = W.copy(alpha = 0.9f))
            Text(f.hop, color = W, fontSize = 11.sp, fontFamily = FontFamily.Monospace,
                modifier = Modifier.align(Alignment.TopEnd).padding(8.dp))
            Pill(f.tag, Color(0x99140638), modifier = Modifier.align(Alignment.BottomStart).padding(8.dp))
        }
        Column(Modifier.padding(10.dp)) {
            Text(f.title, color = C.Ink, fontWeight = FontWeight.Bold, fontSize = 14.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(f.sub, color = C.InkSoft, fontSize = 12.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
    }
}

@Composable
fun NearbyScreen(open: (String) -> Unit) {
    var filter by rememberSaveable { mutableStateOf(0) }
    val shown = when (filter) {
        1 -> feed.filter { it.dest == "chat" }
        2 -> feed.filter { it.dest == "room" }
        3 -> feed.filter { it.ic == Ic.File }
        4 -> feed.filter { it.ic == Ic.Tower }
        else -> feed
    }
    Column(
        Modifier.fillMaxSize().background(C.lightBg).statusBarsPadding().verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Title("Nearby")
            Pill("Demo data", C.Violet)
            Spacer(Modifier.weight(1f))
            Box(Modifier.size(40.dp).border(1.5.dp, C.Ink, CircleShape), Alignment.Center) {
                Icon(Ic.Bell, "Notifications", Modifier.size(20.dp), tint = C.Ink)
            }
            Avatar("JT", Color(0xFFFF9A62), C.Pink)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Tile("New\nPeers", Color(0xFFFF9A62), C.Coral, Ic.User) { open("chat") }
            Tile("Mesh\nRooms", Color(0xFFFF7FD0), Color(0xFFC026D3), Ic.Mesh) { open("room") }
            Tile("LoRa\nLink", Color(0xFF5AA0FF), Color(0xFF2F3FF5), Ic.Tower) { open("share") }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(18.dp)) {
            listOf("All", "Chats", "Rooms", "Files", "LoRa").forEachIndexed { i, t ->
                Text(
                    t, fontSize = 14.sp, color = if (i == filter) C.Ink else C.InkSoft,
                    fontWeight = if (i == filter) FontWeight.Bold else FontWeight.Medium,
                    modifier = Modifier.clickable { filter = i }.padding(vertical = 4.dp),
                )
            }
        }
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(50))
                .background(Brush.horizontalGradient(listOf(Color(0xFF8B5CF6), Color(0xFFD946EF))))
                .padding(horizontal = 16.dp, vertical = 11.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(Ic.Mesh, null, Modifier.size(18.dp), tint = W)
            Text("12 peers in reach", color = W, fontWeight = FontWeight.Bold, fontSize = 14.sp)
            Spacer(Modifier.weight(1f))
            Text("up to 3 hops ›", color = W, fontSize = 13.sp)
        }
        shown.chunked(2).forEach { pair ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                pair.forEach { FeedCard(it, open) }
                if (pair.size == 1) Spacer(Modifier.weight(1f))
            }
        }
    }
}

// ---------------------------------------------------------------- Chat

private data class Msg(
    val text: String, val me: Boolean = false, val voice: Boolean = false,
    val noteLabel: String? = null, val note: String? = null,
    val progress: Float? = null, val status: String? = null, val statusIc: ImageVector? = null,
)

private val waveHeights = listOf(6, 12, 18, 9, 15, 21, 11, 7, 16, 20, 13, 8, 17, 22, 10, 14, 6, 12, 19, 9, 15, 7, 11, 5)

@Composable
private fun Bubble(m: Msg) {
    val fg = if (m.me) Color(0xFF3A0F3C) else W
    Row(Modifier.fillMaxWidth(), horizontalArrangement = if (m.me) Arrangement.End else Arrangement.Start) {
        Column(
            Modifier.widthIn(max = 290.dp).clip(RoundedCornerShape(20.dp)).background(if (m.me) W else glass(0.22f))
                .padding(horizontal = 14.dp, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            if (m.voice) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                    waveHeights.forEach { Box(Modifier.width(3.dp).height(it.dp).clip(RoundedCornerShape(2.dp)).background(fg)) }
                    Text("  0:14", color = fg, fontSize = 12.sp)
                }
            } else {
                Text(m.text, color = fg, fontSize = 15.sp)
            }
            if (m.note != null) {
                Box(Modifier.fillMaxWidth().height(1.dp).background(fg.copy(alpha = 0.4f)))
                Text(m.noteLabel.orEmpty().uppercase(), color = fg.copy(alpha = 0.85f), fontSize = 10.sp, letterSpacing = 0.8.sp)
                Text(m.note, color = fg, fontSize = 14.sp)
            }
            if (m.progress != null) {
                Box(Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(4.dp)).background(Color(0xFFF3D4E0))) {
                    Box(Modifier.fillMaxWidth(m.progress).height(6.dp)
                        .background(Brush.horizontalGradient(listOf(Color(0xFFF0566F), C.Violet))))
                }
            }
            if (m.status != null) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    if (m.statusIc != null) Icon(m.statusIc, null, Modifier.size(13.dp), tint = fg.copy(alpha = 0.8f))
                    Text(m.status, color = fg.copy(alpha = 0.8f), fontSize = 11.sp)
                }
            }
        }
    }
}

@Composable
fun ChatScreen(back: () -> Unit) {
    val msgs = remember {
        mutableStateListOf(
            Msg("", voice = true, noteLabel = "Transcribed on this phone",
                note = "Nandito na kami sa covered court, dala namin ang mga gamot."),
            Msg("We need two more volunteers at the east gate.", noteLabel = "Translated on this phone",
                note = "Kailangan pa namin ng dalawang volunteer sa east gate."),
            Msg("evac-map.jpg · 4.8 MB", me = true, progress = 0.68f, status = "Wi-Fi Aware direct · 68%", statusIc = Ic.File),
            Msg("Papunta na ako. Sabihan si Carlo.", me = true, status = "Held by 3 carriers · expires in 21 h", statusIc = Ic.Shield),
        )
    }
    var draft by rememberSaveable { mutableStateOf("") }
    val listState = rememberLazyListState()
    LaunchedEffect(msgs.size) { listState.animateScrollToItem(msgs.lastIndex) }
    val send = {
        if (draft.isNotBlank()) {
            msgs.add(Msg(draft.trim(), me = true, status = "Not sent · prototype has no radio yet", statusIc = Ic.Shield))
            draft = ""
        }
    }
    Column(Modifier.fillMaxSize().background(C.chatBg).statusBarsPadding().navigationBarsPadding().imePadding()) {
        Row(Modifier.padding(horizontal = 12.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            RoundBtn(Ic.Back, Color.Transparent, onClick = back)
            Avatar("LM", C.Gold, C.Coral)
            Column(Modifier.weight(1f)) {
                Text("Liza M.", color = W, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Icon(Ic.Lock, null, Modifier.size(12.dp), tint = W)
                    Text("End-to-end encrypted · 2 hops", color = W, fontSize = 12.sp)
                }
            }
            RoundBtn(Ic.Shield, glass())
        }
        LazyColumn(Modifier.weight(1f).padding(horizontal = 14.dp), state = listState,
            verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items(msgs) { Bubble(it) }
        }
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(Modifier.weight(1f).clip(RoundedCornerShape(50)).background(glass()).padding(horizontal = 16.dp, vertical = 12.dp)) {
                if (draft.isEmpty()) Text("Message", color = W.copy(alpha = 0.75f), fontSize = 15.sp)
                BasicTextField(draft, { draft = it }, Modifier.fillMaxWidth(), textStyle = TextStyle(color = W, fontSize = 15.sp),
                    cursorBrush = Brush.verticalGradient(listOf(W, W)), maxLines = 4)
            }
            RoundBtn(Ic.Mic, glass())
            RoundBtn(Ic.Send, W, Color(0xFFA12A6B), send)
        }
    }
}

// ---------------------------------------------------------------- Room

@Composable
fun RoomScreen(back: () -> Unit, open: (String) -> Unit) {
    Column(
        Modifier.fillMaxSize().background(C.Night).drawBehind {
            drawRect(Brush.radialGradient(listOf(Color(0xFF3A1FD1), Color.Transparent),
                Offset(size.width * 0.85f, size.height * 0.1f), size.width * 0.9f))
            drawRect(Brush.radialGradient(listOf(Color(0xFFC0189A), Color.Transparent),
                Offset(size.width * 0.05f, size.height * 0.6f), size.width * 0.8f))
        }.statusBarsPadding().navigationBarsPadding()
    ) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            RoundBtn(Ic.Back, Color.Transparent, onClick = back)
            Row(Modifier.clip(RoundedCornerShape(16.dp)).background(glass(0.1f)).padding(6.dp).padding(end = 8.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Avatar("BR", Color(0xFF22B8FF), Color(0xFF5A3DF0), 36.dp)
                Column {
                    Text("Barangay Relief", color = W, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
                    Text("ID 4f2a·91c7", color = W.copy(alpha = 0.75f), fontSize = 11.sp, fontFamily = FontFamily.Monospace)
                }
            }
            Spacer(Modifier.weight(1f))
            RoundBtn(Ic.Share, glass(0.14f)) { open("share") }
        }
        Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Pill("LoRa bridge", glass(0.12f))
            Pill("241 relayed", glass(0.12f))
        }
        Column(Modifier.fillMaxWidth().padding(top = 10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Avatar("AS", Color(0xFFFF7FD0), C.Violet, 76.dp, Modifier.border(3.dp, Color(0xFFFF7FD0), CircleShape).padding(5.dp))
            Text("Ana · host", color = W, fontSize = 13.sp, modifier = Modifier.padding(top = 4.dp))
        }
        Column(Modifier.padding(horizontal = 8.dp, vertical = 16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            peers.chunked(4).forEach { row ->
                Row(Modifier.fillMaxWidth()) {
                    row.forEach { p ->
                        Column(Modifier.weight(1f).clickable { open("chat") }, horizontalAlignment = Alignment.CenterHorizontally) {
                            Box {
                                Avatar(p.initials, p.a, p.b, 58.dp)
                                Text(p.hop, color = C.Cyan, fontSize = 10.sp, fontFamily = FontFamily.Monospace,
                                    modifier = Modifier.align(Alignment.TopEnd).offset(x = 8.dp, y = (-4).dp)
                                        .clip(RoundedCornerShape(50)).background(C.Night)
                                        .border(1.dp, C.Cyan, RoundedCornerShape(50)).padding(horizontal = 5.dp))
                            }
                            Text(p.name, color = W, fontSize = 12.sp, modifier = Modifier.padding(top = 4.dp))
                        }
                    }
                }
            }
        }
        Column(Modifier.weight(1f).padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.Bottom)) {
            LogLine("Rico", " joined through 2 hops")
            LogLine("Paolo", " reached the room over LoRa, 4.2 km")
            LogLine("Ben", " is carrying 4 messages for Carlo")
        }
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Type…", color = W.copy(alpha = 0.7f), fontSize = 15.sp,
                modifier = Modifier.weight(1f).clip(RoundedCornerShape(50)).background(glass(0.14f)).padding(horizontal = 16.dp, vertical = 12.dp))
            RoundBtn(Ic.Mic, glass(0.14f))
            RoundBtn(Ic.File, glass(0.14f))
            RoundBtn(Ic.Tower, glass(0.14f)) { open("share") }
        }
    }
}

@Composable
private fun LogLine(who: String, rest: String) = Row {
    Text(who, color = C.Gold, fontWeight = FontWeight.Bold, fontSize = 14.sp)
    Text(rest, color = W, fontSize = 14.sp)
}

// ---------------------------------------------------------------- Share + radio

@Composable
fun ShareScreen(back: () -> Unit) {
    Column(
        Modifier.fillMaxSize().background(C.shareBg).statusBarsPadding().navigationBarsPadding()
            .verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            RoundBtn(Ic.Back, Color.Transparent, onClick = back)
            Title("Share Tucnet", W)
        }
        Text("No internet needed. Your friend scans, downloads from your phone and installs.", color = W.copy(alpha = 0.9f), fontSize = 14.sp)
        Box(Modifier.align(Alignment.CenterHorizontally).size(200.dp).clip(RoundedCornerShape(22.dp)).background(W).padding(14.dp)) {
            Canvas(Modifier.fillMaxSize()) {
                val n = 25
                val cell = size.width / n
                fun reserved(x: Int, y: Int) = (x < 8 && y < 8) || (x > 16 && y < 8) || (x < 8 && y > 16)
                var s = 7L
                for (y in 0 until n) for (x in 0 until n) {
                    s = (s * 1103515245L + 12345L) and 0x7fffffffL
                    if (!reserved(x, y) && (s shr 16) % 2L == 1L) drawRect(C.Ink, Offset(x * cell, y * cell), Size(cell, cell))
                }
                listOf(0 to 0, 18 to 0, 0 to 18).forEach { (fx, fy) ->
                    drawRect(C.Ink, Offset(fx * cell, fy * cell), Size(7 * cell, 7 * cell))
                    drawRect(W, Offset((fx + 1) * cell, (fy + 1) * cell), Size(5 * cell, 5 * cell))
                    drawRect(C.Violet, Offset((fx + 2) * cell, (fy + 2) * cell), Size(3 * cell, 3 * cell))
                }
            }
        }
        Pill("Placeholder code · sharing not built yet", glass(0.18f), modifier = Modifier.align(Alignment.CenterHorizontally))
        listOf("Scan to join this phone's Wi-Fi", "Open 192.168.49.1:8080", "Install the APK").forEachIndexed { i, t ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.size(24.dp).clip(CircleShape).background(W), Alignment.Center) {
                    Text("${i + 1}", color = Color(0xFF5B21B6), fontWeight = FontWeight.Bold, fontSize = 13.sp)
                }
                Text(t, color = W, fontSize = 15.sp)
            }
        }
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(C.Night.copy(alpha = 0.55f)).padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Ic.Tower, null, Modifier.size(20.dp), tint = W)
                Text("T-Beam · Meshtastic", color = W, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, modifier = Modifier.weight(1f))
                Pill("Sample", C.Mint, Color(0xFF06301F))
            }
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf("915" to "MHz · PH", "7.5" to "SNR dB", "5" to "nodes", "82%" to "battery").forEach { (v, l) ->
                    Column(Modifier.weight(1f).clip(RoundedCornerShape(12.dp)).background(glass(0.1f)).padding(vertical = 8.dp),
                        horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(v, color = W, fontFamily = FontFamily.Monospace, fontSize = 14.sp)
                        Text(l, color = W.copy(alpha = 0.75f), fontSize = 10.sp)
                    }
                }
            }
        }
    }
}

// ---------------------------------------------------------------- Radar

@Composable
fun RadarScreen(open: (String) -> Unit) {
    Column(Modifier.fillMaxSize().background(C.Night).statusBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Title("Radar", W)
        Text("Rings are hop distance. Sample peers.", color = W.copy(alpha = 0.75f), fontSize = 14.sp)
        BoxWithConstraints(Modifier.fillMaxWidth().aspectRatio(1f)) {
            val r = maxWidth / 2
            Canvas(Modifier.fillMaxSize()) {
                for (i in 1..3) drawCircle(C.Cyan.copy(alpha = 0.18f + 0.1f * (3 - i)), size.minDimension / 2 * i / 3.2f, style = Stroke(2f))
                drawCircle(Brush.radialGradient(listOf(C.Violet.copy(alpha = 0.45f), Color.Transparent)), size.minDimension / 2)
            }
            Avatar("JT", Color(0xFFFF9A62), C.Pink, 46.dp, Modifier.align(Alignment.Center))
            peers.take(6).forEachIndexed { i, p ->
                val ring = p.hop.toInt()
                val ang = Math.toRadians((i * 61 + 20).toDouble())
                val d = r * (ring / 3.2f)
                Avatar(p.initials, p.a, p.b, 40.dp,
                    Modifier.align(Alignment.Center).offset(x = d * cos(ang).toFloat(), y = d * sin(ang).toFloat()).clickable { open("chat") })
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Pill("6 on BLE", glass(0.14f)); Pill("1 on LoRa", glass(0.14f)); Pill("1 away", glass(0.14f))
        }
    }
}

// ---------------------------------------------------------------- Vault

@Composable
fun VaultScreen(open: (String) -> Unit) {
    var relay by rememberSaveable { mutableStateOf(true) }
    Column(Modifier.fillMaxSize().background(C.lightBg).statusBarsPadding().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Title("Vault")
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp))
            .background(Brush.linearGradient(listOf(Color(0xFF5A3DF0), Color(0xFFD946EF)))).padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("YOUR IDENTITY", color = W.copy(alpha = 0.8f), fontSize = 11.sp, letterSpacing = 1.sp)
            Text("TN-4F2A-91C7-D03E", color = W, fontFamily = FontFamily.Monospace, fontSize = 20.sp, fontWeight = FontWeight.Bold)
            Text("Sample ID. In the real app this is made on your phone, with no phone number or e-mail.", color = W, fontSize = 13.sp)
        }
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(W).padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text("Relay mode", color = C.Ink, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                Text("Carry encrypted messages for others, up to 24 h", color = C.InkSoft, fontSize = 12.sp)
            }
            Switch(relay, { relay = it })
        }
        VaultRow(Ic.Share, "Share Tucnet offline", "Send the app to a nearby phone") { open("share") }
        VaultRow(Ic.Tower, "LoRa radio", "Pair a Meshtastic board") { open("share") }
        Text("Prototype build. Every screen shows sample data. Mesh networking, encryption, LoRa and on-device AI are not implemented yet.",
            color = C.Ink, fontSize = 13.sp,
            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Color(0xFFFFE3EF)).padding(14.dp))
    }
}

@Composable
private fun VaultRow(ic: ImageVector, title: String, sub: String, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(W).clickable(onClick = onClick).padding(16.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Icon(ic, null, Modifier.size(22.dp), tint = C.Violet)
        Column(Modifier.weight(1f)) {
            Text(title, color = C.Ink, fontWeight = FontWeight.Bold, fontSize = 15.sp)
            Text(sub, color = C.InkSoft, fontSize = 12.sp)
        }
        Text("›", color = C.InkSoft, fontSize = 20.sp)
    }
}

// ---------------------------------------------------------------- Moments + Chats

@Composable
fun MomentsScreen() {
    Column(Modifier.fillMaxSize().background(C.lightBg).statusBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Title("Moments")
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(W).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(Ic.Spark, null, Modifier.size(40.dp), tint = C.Pink)
            Text("Nothing nearby yet", color = C.Ink, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            Text("Posts from people in reach will appear here once the mesh is built.", color = C.InkSoft, fontSize = 13.sp)
        }
    }
}

@Composable
fun ChatsScreen(open: (String) -> Unit) {
    Column(Modifier.fillMaxSize().background(C.lightBg).statusBarsPadding().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Title("Chats")
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(W).clickable { open("room") }.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Avatar("BR", Color(0xFF22B8FF), Color(0xFF5A3DF0), 46.dp)
            Column(Modifier.weight(1f)) {
                Text("Barangay Relief", color = C.Ink, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                Text("Ben is carrying 4 messages for Carlo", color = C.InkSoft, fontSize = 12.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Pill("Room", C.Violet)
        }
        peers.take(5).forEach { p ->
            Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(W).clickable { open("chat") }.padding(12.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Avatar(p.initials, p.a, p.b, 46.dp)
                Column(Modifier.weight(1f)) {
                    Text(p.name, color = C.Ink, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                    Text("${p.hop} hop${if (p.hop == "1") "" else "s"} away · encrypted", color = C.InkSoft, fontSize = 12.sp)
                }
                Icon(Ic.Lock, null, Modifier.size(16.dp), tint = C.InkSoft)
            }
        }
    }
}

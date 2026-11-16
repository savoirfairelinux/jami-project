package org.tucnet.app

import androidx.activity.compose.rememberLauncherForActivityResult
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
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
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

@Composable
private fun BigButton(text: String, enabled: Boolean = true, onClick: () -> Unit) {
    Text(
        text, color = Color(0xFF5B21B6), fontWeight = FontWeight.Bold, fontSize = 16.sp,
        modifier = Modifier.clip(RoundedCornerShape(50)).background(W.copy(alpha = if (enabled) 1f else 0.5f))
            .clickable(enabled = enabled, onClick = onClick).padding(horizontal = 24.dp, vertical = 13.dp),
    )
}

@Composable
private fun Field(value: String, onChange: (String) -> Unit, hint: String, lines: Int = 1) {
    Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(glass()).padding(horizontal = 16.dp, vertical = 14.dp)) {
        if (value.isEmpty()) Text(hint, color = W.copy(alpha = 0.7f), fontSize = 16.sp)
        BasicTextField(value, onChange, Modifier.fillMaxWidth(), textStyle = TextStyle(color = W, fontSize = 16.sp),
            cursorBrush = Brush.verticalGradient(listOf(W, W)), singleLine = lines == 1, maxLines = lines)
    }
}

private fun contactName(id: String) = Mesh.contacts.firstOrNull { it.id == id }?.name ?: "Unknown"
private fun inReach(id: String) = Mesh.near.values.any { it.contactId == id }

// ---------------------------------------------------------------- Onboarding

@Composable
fun OnboardingScreen() {
    var name by rememberSaveable { mutableStateOf("") }
    Column(
        Modifier.fillMaxSize().background(C.shareBg).statusBarsPadding().navigationBarsPadding().imePadding()
            .verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Spacer(Modifier.height(40.dp))
        Icon(Ic.Mesh, null, Modifier.size(56.dp), tint = W)
        Text("Tucnet", color = W, fontSize = 40.sp, fontWeight = FontWeight.ExtraBold)
        Text("Chat with people nearby over Bluetooth. No internet, no SIM, no account.", color = W, fontSize = 17.sp)
        Text("Your identity is a set of keys made on this phone. Nothing is sent to a server.", color = W.copy(alpha = 0.85f), fontSize = 14.sp)
        Field(name, { name = it.take(40) }, "Your name")
        BigButton("Create my identity", enabled = name.isNotBlank()) { Mesh.createIdentity(name) }
    }
}

// ---------------------------------------------------------------- Nearby

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
private fun RowScope.ContactCard(c: ContactUi, open: (String) -> Unit) {
    val (a, b) = colorsFor(c.id)
    val near = inReach(c.id)
    val last = Mesh.messages.lastOrNull { it.contact == c.id }
    Column(Modifier.weight(1f).clip(RoundedCornerShape(18.dp)).background(W).clickable { open("chat:${c.id}") }) {
        Box(Modifier.fillMaxWidth().height(96.dp).background(Brush.linearGradient(listOf(a, b)))) {
            Text(initials(c.name), color = W, fontSize = 34.sp, fontWeight = FontWeight.ExtraBold, modifier = Modifier.align(Alignment.Center))
            Pill(if (near) "In reach" else "Out of reach", Color(0x99140638), modifier = Modifier.align(Alignment.BottomStart).padding(8.dp))
        }
        Column(Modifier.padding(10.dp)) {
            Text(c.name, color = C.Ink, fontWeight = FontWeight.Bold, fontSize = 14.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(last?.text ?: "No messages yet", color = C.InkSoft, fontSize = 12.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

@Composable
fun NearbyScreen(open: (String) -> Unit, requestRadio: () -> Unit) {
    val me = Mesh.myCard
    Column(
        Modifier.fillMaxSize().background(C.lightBg).statusBarsPadding().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Title("Nearby")
            Pill(if (Mesh.radio == "On") "Mesh on" else "Mesh off", if (Mesh.radio == "On") C.Violet else C.InkSoft)
            Spacer(Modifier.weight(1f))
            if (me != null) colorsFor(me.idHex).let { (a, b) -> Avatar(initials(me.name), a, b, modifier = Modifier.clickable { open("code") }) }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Tile("Add\ncontact", Color(0xFFFF9A62), C.Coral, Ic.User) { open("add") }
            Tile("My\ncode", Color(0xFFFF7FD0), Color(0xFFC026D3), Ic.Share) { open("code") }
            Tile(if (Mesh.relay) "Relay\non" else "Relay\noff", Color(0xFF5AA0FF), Color(0xFF2F3FF5), Ic.Mesh) { Mesh.changeRelay(!Mesh.relay) }
        }
        if (Mesh.radio != "On") {
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Color(0xFFFFE3EF)).clickable(onClick = requestRadio).padding(14.dp)) {
                Text(Mesh.radio, color = C.Ink, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                Text("Turn on Bluetooth and allow the Nearby devices permission, then tap here.", color = C.Ink, fontSize = 13.sp)
            }
        }
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(50))
                .background(Brush.horizontalGradient(listOf(Color(0xFF8B5CF6), Color(0xFFD946EF))))
                .padding(horizontal = 16.dp, vertical = 11.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(Ic.Mesh, null, Modifier.size(18.dp), tint = W)
            Text("${Mesh.near.size} in reach", color = W, fontWeight = FontWeight.Bold, fontSize = 14.sp)
            Spacer(Modifier.weight(1f))
            Text("${Mesh.links} linked · carrying ${Mesh.carried}", color = W, fontSize = 13.sp)
        }
        if (Mesh.contacts.isEmpty()) {
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(W).padding(22.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("No contacts yet", color = C.Ink, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                Text("Tap Add contact and scan a friend's Tucnet code. Only one of you needs to scan.", color = C.InkSoft, fontSize = 13.sp)
            }
        }
        Mesh.contacts.chunked(2).forEach { pair ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                pair.forEach { ContactCard(it, open) }
                if (pair.size == 1) Spacer(Modifier.weight(1f))
            }
        }
    }
}

// ---------------------------------------------------------------- Chat

@Composable
private fun Bubble(m: MsgUi) {
    val fg = if (m.me) Color(0xFF3A0F3C) else W
    Row(Modifier.fillMaxWidth(), horizontalArrangement = if (m.me) Arrangement.End else Arrangement.Start) {
        Column(
            Modifier.widthIn(max = 290.dp).clip(RoundedCornerShape(20.dp)).background(if (m.me) W else glass(0.22f))
                .padding(horizontal = 14.dp, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(m.text, color = fg, fontSize = 15.sp)
            if (m.me) {
                val status = when (m.status) {
                    0 -> "Waiting for a device in reach"
                    1 -> "Handed to the mesh · not delivered yet"
                    else -> "Delivered"
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Icon(if (m.status == 2) Ic.Lock else Ic.Shield, null, Modifier.size(13.dp), tint = fg.copy(alpha = 0.8f))
                    Text(status, color = fg.copy(alpha = 0.8f), fontSize = 11.sp)
                }
            }
        }
    }
}

@Composable
fun ChatScreen(contactId: String, back: () -> Unit) {
    val msgs = Mesh.messages.filter { it.contact == contactId }
    var draft by rememberSaveable { mutableStateOf("") }
    val listState = rememberLazyListState()
    val name = contactName(contactId)
    val (a, b) = colorsFor(contactId)
    DisposableEffect(contactId) { Mesh.openChat = contactId; onDispose { Mesh.openChat = null } }
    LaunchedEffect(msgs.size) { if (msgs.isNotEmpty()) listState.animateScrollToItem(msgs.lastIndex) }
    val send = { if (draft.isNotBlank()) { Mesh.send(contactId, draft.trim().take(4000)); draft = "" } }

    Column(Modifier.fillMaxSize().background(C.chatBg).statusBarsPadding().navigationBarsPadding().imePadding()) {
        Row(Modifier.padding(horizontal = 12.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            RoundBtn(Ic.Back, Color.Transparent, onClick = back)
            Avatar(initials(name), a, b)
            Column(Modifier.weight(1f)) {
                Text(name, color = W, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Icon(Ic.Lock, null, Modifier.size(12.dp), tint = W)
                    Text("End-to-end encrypted · " + if (inReach(contactId)) "in reach" else "out of reach", color = W, fontSize = 12.sp)
                }
            }
        }
        Text(shortId(contactId), color = W.copy(alpha = 0.8f), fontSize = 11.sp, fontFamily = FontFamily.Monospace,
            modifier = Modifier.padding(horizontal = 16.dp))
        LazyColumn(Modifier.weight(1f).padding(horizontal = 14.dp, vertical = 8.dp), state = listState,
            verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items(msgs) { Bubble(it) }
        }
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(Modifier.weight(1f).clip(RoundedCornerShape(50)).background(glass()).padding(horizontal = 16.dp, vertical = 12.dp)) {
                if (draft.isEmpty()) Text("Message", color = W.copy(alpha = 0.75f), fontSize = 15.sp)
                BasicTextField(draft, { draft = it }, Modifier.fillMaxWidth(), textStyle = TextStyle(color = W, fontSize = 15.sp),
                    cursorBrush = Brush.verticalGradient(listOf(W, W)), maxLines = 4)
            }
            RoundBtn(Ic.Send, W, Color(0xFFA12A6B), send)
        }
    }
}

// ---------------------------------------------------------------- Add contact + my code

@Composable
fun AddContactScreen(back: () -> Unit, open: (String) -> Unit) {
    var pasted by rememberSaveable { mutableStateOf("") }
    var error by rememberSaveable { mutableStateOf<String?>(null) }
    val add: (String) -> Unit = { text ->
        error = Mesh.addContact(text)
        if (error == null) org.tucnet.core.Card.fromText(text)?.let { open("chat:${it.idHex}") }
    }
    val scanner = rememberLauncherForActivityResult(ScanContract()) { result -> result.contents?.let(add) }
    Column(
        Modifier.fillMaxSize().background(C.shareBg).statusBarsPadding().navigationBarsPadding().imePadding()
            .verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            RoundBtn(Ic.Back, Color.Transparent, onClick = back)
            Title("Add contact", W)
        }
        Text("Scan the code on your friend's phone (My code). Scanning in person is how you know the keys are really theirs.",
            color = W.copy(alpha = 0.9f), fontSize = 14.sp)
        BigButton("Scan a code") {
            scanner.launch(ScanOptions().setDesiredBarcodeFormats(ScanOptions.QR_CODE).setBeepEnabled(false)
                .setOrientationLocked(true).setPrompt("Point at a Tucnet code"))
        }
        Text("Or paste a code someone sent you", color = W, fontWeight = FontWeight.Bold, fontSize = 15.sp)
        Field(pasted, { pasted = it; error = null }, "tucnet1:…", lines = 5)
        BigButton("Add", enabled = pasted.isNotBlank()) { add(pasted) }
        error?.let { Text(it, color = C.Gold, fontWeight = FontWeight.Bold, fontSize = 14.sp) }
    }
}

@Composable
private fun QrCode(text: String, modifier: Modifier) {
    val matrix = remember(text) {
        QRCodeWriter().encode(text, BarcodeFormat.QR_CODE, 0, 0, mapOf(EncodeHintType.MARGIN to 0))
    }
    Canvas(modifier) {
        val cell = size.width / matrix.width
        for (y in 0 until matrix.height) for (x in 0 until matrix.width) {
            if (matrix.get(x, y)) drawRect(C.Ink, Offset(x * cell, y * cell), Size(cell + 0.5f, cell + 0.5f))
        }
    }
}

@Composable
fun MyCodeScreen(back: () -> Unit) {
    val card = Mesh.myCard ?: return
    val text = remember(card.idHex) { card.toText() }
    val clipboard = LocalClipboardManager.current
    var copied by remember { mutableStateOf(false) }
    Column(
        Modifier.fillMaxSize().background(C.shareBg).statusBarsPadding().navigationBarsPadding()
            .verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            RoundBtn(Ic.Back, Color.Transparent, onClick = back)
            Title("My code", W)
        }
        Text("Let a friend scan this with Add contact. It holds your public keys only.", color = W.copy(alpha = 0.9f), fontSize = 14.sp)
        Box(Modifier.align(Alignment.CenterHorizontally).fillMaxWidth(0.82f).aspectRatio(1f).clip(RoundedCornerShape(22.dp)).background(W).padding(16.dp)) {
            QrCode(text, Modifier.fillMaxSize())
        }
        Text(card.name, color = W, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp, modifier = Modifier.align(Alignment.CenterHorizontally))
        Text(shortId(card.idHex), color = W, fontFamily = FontFamily.Monospace, fontSize = 14.sp, modifier = Modifier.align(Alignment.CenterHorizontally))
        Box(Modifier.align(Alignment.CenterHorizontally)) {
            BigButton(if (copied) "Copied" else "Copy code as text") { clipboard.setText(AnnotatedString(text)); copied = true }
        }
    }
}

// ---------------------------------------------------------------- Radar

@Composable
fun RadarScreen(open: (String) -> Unit) {
    val devices = Mesh.near.values.sortedBy { it.hint }
    Column(Modifier.fillMaxSize().background(C.Night).statusBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Title("Radar", W)
        Text("Tucnet phones this device can hear right now. Closer to the centre means a stronger signal.", color = W.copy(alpha = 0.75f), fontSize = 14.sp)
        BoxWithConstraints(Modifier.fillMaxWidth().aspectRatio(1f)) {
            val r = maxWidth / 2
            Canvas(Modifier.fillMaxSize()) {
                for (i in 1..3) drawCircle(C.Cyan.copy(alpha = 0.18f + 0.1f * (3 - i)), size.minDimension / 2 * i / 3.2f, style = Stroke(2f))
                drawCircle(Brush.radialGradient(listOf(C.Violet.copy(alpha = 0.45f), Color.Transparent)), size.minDimension / 2)
            }
            Mesh.myCard?.let { me -> colorsFor(me.idHex).let { (a, b) -> Avatar(initials(me.name), a, b, 46.dp, Modifier.align(Alignment.Center)) } }
            devices.forEach { d ->
                val ring = when { d.rssi > -60 -> 1; d.rssi > -80 -> 2; else -> 3 }
                val ang = Math.toRadians(((d.hint.take(4).toIntOrNull(16) ?: 0) % 360).toDouble())
                val dist = r * (ring / 3.2f)
                val mod = Modifier.align(Alignment.Center).offset(x = dist * cos(ang).toFloat(), y = dist * sin(ang).toFloat())
                if (d.contactId != null) {
                    val (a, b) = colorsFor(d.contactId)
                    Avatar(initials(contactName(d.contactId)), a, b, 40.dp, mod.clickable { open("chat:${d.contactId}") })
                } else {
                    Avatar("?", Color(0xFF8A78B8), Color(0xFF3D2A7C), 34.dp, mod)
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Pill("${devices.count { it.contactId != null }} contacts", glass(0.14f))
            Pill("${devices.count { it.contactId == null }} other devices", glass(0.14f))
            Pill("${Mesh.links} linked", glass(0.14f))
        }
        if (devices.isEmpty()) Text("Nobody in reach. Another phone needs Tucnet open with Bluetooth on.", color = W.copy(alpha = 0.75f), fontSize = 14.sp)
    }
}

// ---------------------------------------------------------------- Vault

@Composable
fun VaultScreen(open: (String) -> Unit) {
    val card = Mesh.myCard ?: return
    Column(Modifier.fillMaxSize().background(C.lightBg).statusBarsPadding().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Title("Vault")
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp))
            .background(Brush.linearGradient(listOf(Color(0xFF5A3DF0), Color(0xFFD946EF)))).clickable { open("code") }.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("YOUR IDENTITY", color = W.copy(alpha = 0.8f), fontSize = 11.sp, letterSpacing = 1.sp)
            Text(card.name, color = W, fontSize = 20.sp, fontWeight = FontWeight.ExtraBold)
            Text(shortId(card.idHex), color = W, fontFamily = FontFamily.Monospace, fontSize = 15.sp)
            Text("Keys were made on this phone and are locked by the Android Keystore. Tap to show your code.", color = W, fontSize = 13.sp)
        }
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(W).padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text("Relay mode", color = C.Ink, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                Text("Carry other people's encrypted messages for up to 24 h. You cannot read them.", color = C.InkSoft, fontSize = 12.sp)
            }
            Switch(Mesh.relay, { Mesh.changeRelay(it) })
        }
        Stat("Bluetooth mesh", Mesh.radio)
        Stat("Devices in reach", "${Mesh.near.size}")
        Stat("Active links", "${Mesh.links}")
        Stat("Packets being carried", "${Mesh.carried}")
        Text("Version 0.2. Works today: identity, QR contacts, encrypted 1:1 text, Bluetooth relay, 24 h store-and-forward. " +
            "Not built yet: Wi-Fi Aware files, rooms, LoRa, on-device AI, app sharing.",
            color = C.Ink, fontSize = 13.sp,
            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Color(0xFFFFE3EF)).padding(14.dp))
    }
}

@Composable
private fun Stat(label: String, value: String) {
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(W).padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, color = C.Ink, fontSize = 15.sp, modifier = Modifier.weight(1f))
        Text(value, color = C.Violet, fontWeight = FontWeight.Bold, fontSize = 15.sp)
    }
}

// ---------------------------------------------------------------- Chats

@Composable
fun ChatsScreen(open: (String) -> Unit) {
    Column(Modifier.fillMaxSize().background(C.lightBg).statusBarsPadding().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Title("Chats")
        if (Mesh.contacts.isEmpty()) {
            Text("No chats yet. Add a contact from the Mesh tab.", color = C.InkSoft, fontSize = 14.sp)
        }
        Mesh.contacts.sortedByDescending { c -> Mesh.messages.lastOrNull { it.contact == c.id }?.ts ?: 0 }.forEach { c ->
            val (a, b) = colorsFor(c.id)
            val last = Mesh.messages.lastOrNull { it.contact == c.id }
            Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(W).clickable { open("chat:${c.id}") }.padding(12.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Avatar(initials(c.name), a, b, 46.dp)
                Column(Modifier.weight(1f)) {
                    Text(c.name, color = C.Ink, fontWeight = FontWeight.Bold, fontSize = 15.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(last?.text ?: "No messages yet", color = C.InkSoft, fontSize = 12.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                if (inReach(c.id)) Pill("In reach", C.Violet)
            }
        }
    }
}

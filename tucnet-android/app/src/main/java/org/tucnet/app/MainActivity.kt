package org.tucnet.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContent { App() }
    }
}

private val tabs: List<Pair<String, ImageVector>> = listOf(
    "Mesh" to Ic.Mesh, "Radar" to Ic.Radar, "Vault" to Ic.Shield, "Moments" to Ic.Spark, "Chats" to Ic.Chat,
)

@Composable
fun App() {
    var tab by rememberSaveable { mutableStateOf(0) }
    // Full-screen destination shown above the tabs: "chat", "room", "share" or null.
    var overlay by rememberSaveable { mutableStateOf<String?>(null) }
    val open: (String) -> Unit = { overlay = it }
    val close = { overlay = null }

    BackHandler(enabled = overlay != null || tab != 0) { if (overlay != null) overlay = null else tab = 0 }

    when (overlay) {
        "chat" -> ChatScreen(close)
        "room" -> RoomScreen(close, open)
        "share" -> ShareScreen(close)
        else -> Column(Modifier.fillMaxSize().background(C.Nav)) {
            Box(Modifier.weight(1f).fillMaxWidth()) {
                when (tab) {
                    0 -> NearbyScreen(open)
                    1 -> RadarScreen(open)
                    2 -> VaultScreen(open)
                    3 -> MomentsScreen()
                    else -> ChatsScreen(open)
                }
            }
            Row(
                Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 8.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.SpaceAround,
            ) {
                tabs.forEachIndexed { i, (label, ic) ->
                    val active = i == tab
                    Column(
                        Modifier
                            .clip(RoundedCornerShape(14.dp))
                            .background(
                                if (active) Brush.linearGradient(listOf(Color(0xFF4F7BFF), C.Violet))
                                else Brush.linearGradient(listOf(Color.Transparent, Color.Transparent))
                            )
                            .clickable { tab = i }
                            .padding(horizontal = 12.dp, vertical = 7.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        val tint = if (active) Color.White else Color(0xFFB9A6E6)
                        Icon(ic, label, Modifier.size(22.dp), tint = tint)
                        Text(label, color = tint, fontSize = 10.sp)
                    }
                }
            }
        }
    }
}

package org.tucnet.app

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

object C {
    val Ink = Color(0xFF1D0B47)
    val InkSoft = Color(0xFF8A78B8)
    val Violet = Color(0xFF7C3AED)
    val Pink = Color(0xFFE93D98)
    val Coral = Color(0xFFF2603D)
    val Blue = Color(0xFF2F5FF5)
    val Mint = Color(0xFF34E3A8)
    val Cyan = Color(0xFF7FE7FF)
    val Gold = Color(0xFFFFD34D)
    val Night = Color(0xFF0D0633)
    val Nav = Color(0xFF231067)
    val lightBg = Brush.verticalGradient(listOf(Color(0xFFF3E9FF), Color(0xFFE9D7FF), Color(0xFFDCC6FF)))
    val chatBg = Brush.verticalGradient(listOf(Color(0xFFFF8F7A), Color(0xFFF0566F), Color(0xFFA12A6B)))
    val shareBg = Brush.verticalGradient(listOf(Color(0xFF2A1380), Color(0xFF5B21B6), Color(0xFFD946EF)))
}

private fun circle(cx: Float, cy: Float, r: Float) =
    "M${cx - r},${cy}a$r,$r 0 1,0 ${2 * r},0a$r,$r 0 1,0 ${-2 * r},0"

private fun icon(vararg d: String): ImageVector =
    ImageVector.Builder(defaultWidth = 24.dp, defaultHeight = 24.dp, viewportWidth = 24f, viewportHeight = 24f).apply {
        d.forEach {
            addPath(
                pathData = addPathNodes(it), fill = null, stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.8f, strokeLineCap = StrokeCap.Round, strokeLineJoin = StrokeJoin.Round,
            )
        }
    }.build()

object Ic {
    val Bell = icon("M6 16v-5a6 6 0 1 1 12 0v5l2 2H4zM10 21a2 2 0 0 0 4 0")
    val Back = icon("M15 5l-7 7 7 7")
    val Send = icon("M4 12l16-8-6 16-3-6z")
    val Mic = icon("M9 6a3 3 0 0 1 6 0v5a3 3 0 0 1-6 0zM5 11a7 7 0 0 0 14 0M12 18v3")
    val Lock = icon("M7 11h10a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2zM8 11V8a4 4 0 0 1 8 0v3")
    val Mesh = icon(circle(5f, 6f, 2.2f), circle(19f, 6f, 2.2f), circle(12f, 18f, 2.2f), "M7.2 6h9.6M6 8l5 8M18 8l-5 8")
    val Radar = icon(circle(12f, 12f, 9f), circle(12f, 12f, 4f), "M12 12l6-6")
    val Shield = icon("M12 3l7 3v6c0 4.5-3 7.5-7 9-4-1.5-7-4.5-7-9V6z")
    val Spark = icon("M12 3l2.2 6.8L21 12l-6.8 2.2L12 21l-2.2-6.8L3 12l6.8-2.2z")
    val Chat = icon("M4 5h16v11H9l-5 4z")
    val Tower = icon(circle(12f, 9f, 1.6f), "M12 11v10M8 21h8M7.5 5a6 6 0 0 0 0 8M16.5 5a6 6 0 0 1 0 8")
    val Share = icon("M12 15V4M8 8l4-4 4 4M5 13v6h14v-6")
    val File = icon("M7 3h7l4 4v14H7zM14 3v4h4")
    val User = icon(circle(12f, 8f, 4f), "M4 21a8 8 0 0 1 16 0")
}

data class Peer(val initials: String, val name: String, val a: Color, val b: Color, val hop: String)

val peers = listOf(
    Peer("BK", "Ben", Color(0xFFFF9A62), Color(0xFFE93D98), "1"),
    Peer("LM", "Liza", Color(0xFF34E3A8), Color(0xFF2F5FF5), "1"),
    Peer("RS", "Rico", Color(0xFFFFD34D), Color(0xFFF2603D), "2"),
    Peer("MJ", "Mia", Color(0xFF7FE7FF), Color(0xFF7C3AED), "2"),
    Peer("TG", "Tess", Color(0xFFFF7FD0), Color(0xFFF2603D), "3"),
    Peer("DN", "Dan", Color(0xFF5AA0FF), Color(0xFF0C8F6C), "3"),
    Peer("PC", "Paolo", Color(0xFFD946EF), Color(0xFF2F3FF5), "LoRa"),
    Peer("CD", "Carlo", Color(0xFF8A78B8), Color(0xFF3D2A7C), "away"),
)

@Composable
fun Avatar(initials: String, a: Color, b: Color, size: Dp = 40.dp, modifier: Modifier = Modifier) {
    Box(
        modifier.size(size).clip(CircleShape).background(Brush.linearGradient(listOf(a, b))),
        contentAlignment = Alignment.Center,
    ) {
        Text(initials, color = Color.White, fontWeight = FontWeight.ExtraBold, fontSize = (size.value * 0.34f).sp)
    }
}

@Composable
fun Pill(text: String, bg: Color, fg: Color = Color.White, modifier: Modifier = Modifier) {
    Text(
        text, color = fg, fontSize = 11.sp, fontWeight = FontWeight.Bold, maxLines = 1,
        modifier = modifier.clip(RoundedCornerShape(50)).background(bg).padding(horizontal = 9.dp, vertical = 3.dp),
    )
}

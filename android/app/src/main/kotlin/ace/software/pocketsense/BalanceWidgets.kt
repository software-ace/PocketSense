package ace.software.pocketsense

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Build
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.view.View
import android.widget.RemoteViews
import io.flutter.plugin.common.MethodChannel
import kotlin.math.ceil
import kotlin.math.hypot

// Home-screen widgets with amounts, which Settings → Amounts on widgets turns
// on (••• otherwise), in the look Settings → Widget style picks. Nothing is
// saved for them but that look: while the app runs, Dart sends finished text
// (HomeWidgets, channel pocketsense/widgets), and only the views Android
// holds keep it. Until then, or after a reboot, they ask to open the app,
// which goes through the app lock like any launch.
abstract class BalanceWidget(private val overview: Boolean) : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val style = BalanceWidgets.savedStyle(context)
        for (id in ids) manager.updateAppWidget(id, BalanceWidgets.views(context, style, overview, null, rtl = null, id = id))
        // Placed while the app runs: fill it in now.
        BalanceWidgets.channel?.invokeMethod("refresh", null)
    }
}

// Total balance, and spending on a day.
class OverviewWidget : BalanceWidget(overview = true)

// One account's balance; it asks which account on its first tap.
class AccountWidget : BalanceWidget(overview = false)

// How each style draws. Sizes are dp; colours ARGB. bar: hidden amounts are
// blacked out rather than shown as three squares. brand: the Overview shows
// "Pocket Sense" (a console's badge, a receipt's header). Plain is the first
// design: system-font TextViews whose colours follow light and dark mode.
enum class WidgetStyle(
    val overviewLayout: Int, val accountLayout: Int,
    val labelFont: String, val amountFont: String, val bold: Boolean,
    val labelColor: Long, val amountColor: Long, val amount2Color: Long,
    val labelDp: Float, val amountDp: Float, val amount2Dp: Float, val hintDp: Float,
    val hintWidthDp: Int, val hintLines: Int, val bar: Boolean, val brandDp: Float, val brandColor: Long,
    val quickAddLayout: Int, val quickAddFont: String?, val quickAddDp: Float, val quickAddExpense: Long, val quickAddIncome: Long,
) {
    LEATHER(R.layout.widget_overview_leather, R.layout.widget_account_leather, "silkscreen", "vt323", false,
        0xFFB3ADA3, 0xFFF4F1EA, 0xFFF4F1EA, 9f, 26f, 20f, 8f, 116, 2, false, 0f, 0,
        R.layout.quick_add_leather, "silkscreen", 8.5f, 0xFFE8A79E, 0xFFAFD8A8),
    COINS(R.layout.widget_overview_coins, R.layout.widget_account_coins, "pixelify", "pixelify", true,
        0xFF6B5A45, 0xFF2B2118, 0xFFA63D17, 11f, 22f, 17f, 9.5f, 90, 3, false, 0f, 0,
        R.layout.quick_add_coins, "pixelify", 11f, 0xFFA63D17, 0xFF2B2118),
    LCD(R.layout.widget_overview_lcd, R.layout.widget_account_lcd, "vt323", "vt323", false,
        0xFF0F380F, 0xFF0F380F, 0xFF0F380F, 14f, 24f, 19f, 11f, 90, 3, false, 7f, 0xFFD8D6E4,
        R.layout.quick_add_lcd, "vt323", 14f, 0xFF3A3A52, 0xFF3A3A52),
    RECEIPT(R.layout.widget_overview_receipt, R.layout.widget_account_receipt, "vt323", "vt323", false,
        0xFF57524A, 0xFF1F1D1A, 0xFF1F1D1A, 14f, 26f, 20f, 12f, 136, 2, true, 10f, 0xFF1F1D1A,
        R.layout.quick_add_receipt, "vt323", 15f, 0xFF1F1D1A, 0xFF1F1D1A),
    PLAIN(R.layout.widget_overview_plain, R.layout.widget_account_plain, "", "", false,
        0, 0, 0, 0f, 0f, 0f, 0f, 0, 2, false, 0f, 0,
        R.layout.quick_add_widget, null, 0f, 0, 0);

    companion object {
        fun of(key: String?) = values().firstOrNull { it.name.equals(key, ignoreCase = true) } ?: LEATHER
    }
}

object BalanceWidgets {
    const val ACTION_CHOOSE_ACCOUNT = "ace.software.pocketsense.CHOOSE_WIDGET_ACCOUNT"
    private const val PREFS = "balance_widgets"
    private const val HIDDEN = "•••"

    // Set while a Flutter engine runs (MainActivity).
    var channel: MethodChannel? = null

    private fun placed(context: Context, provider: Class<*>): IntArray =
        AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context, provider))

    fun ids(context: Context): Map<String, List<Int>> = mapOf(
        "overview" to placed(context, OverviewWidget::class.java).toList(),
        "account" to placed(context, AccountWidget::class.java).toList(),
    )

    // Only the look and Quick add's words are kept (never an amount), for
    // after a reboot: the placeholder wears the style, Quick add the words.
    fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun savedStyle(context: Context) = WidgetStyle.of(prefs(context).getString("style", null))

    // Each item: id, label, amount, hidden, and for Overview label2, amount2
    // and (while amounts are hidden) hint. An Account widget without an
    // account has choose = true.
    // From HomeWidgets: style, rtl, the words in the app's language (stamp,
    // hiddenLabel, and Quick add's expense, income, voice) and the widgets.
    fun show(context: Context, args: Map<*, *>) {
        @Suppress("UNCHECKED_CAST")
        val widgets = args["widgets"] as List<Map<String, Any?>>
        val style = WidgetStyle.of(args["style"] as String?)
        val rtl = args["rtl"] == true
        val stamp = args["stamp"] as String?
        val hiddenLabel = args["hiddenLabel"] as String?
        // Sent with every data change; written and redrawn only when they differ.
        val prefs = prefs(context)
        val words = listOf("expense", "income", "voice").associateWith { args[it] as String? }
        val same = prefs.getString("style", null) == style.name && prefs.contains("rtl") && prefs.getBoolean("rtl", false) == rtl &&
            words.all { (k, v) -> v == null || prefs.getString(k, null) == v }
        if (!same) {
            prefs.edit().apply {
                putString("style", style.name)
                putBoolean("rtl", rtl)
                for ((k, v) in words) v?.let { putString(k, it) }
            }.commit()
            QuickAddWidget.restyle(context, style)
        }
        val manager = AppWidgetManager.getInstance(context)
        val overview = placed(context, OverviewWidget::class.java).toSet()
        for (w in widgets) {
            val id = (w["id"] as Number).toInt()
            manager.updateAppWidget(id, views(context, style, id in overview, w, rtl, id, stamp, hiddenLabel))
        }
    }

    // After Erase all data: back to asking to open the app.
    fun clear(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val style = savedStyle(context)
        for (id in placed(context, OverviewWidget::class.java)) manager.updateAppWidget(id, views(context, style, true, null, null, id))
        for (id in placed(context, AccountWidget::class.java)) manager.updateAppWidget(id, views(context, style, false, null, null, id))
    }

    // w null: the placeholder, which asks to open the app. rtl null: the phone's direction.
    fun views(context: Context, style: WidgetStyle, overview: Boolean, w: Map<String, Any?>?, rtl: Boolean?, id: Int,
              stampWord: String? = null, hiddenLabel: String? = null): RemoteViews {
        val v = RemoteViews(context.packageName, if (overview) style.overviewLayout else style.accountLayout)
        val choose = w?.get("choose") == true
        // A sleeping cat while amounts are hidden; awake to greet a new widget.
        val asleep = w == null || (w["hidden"] == true && !choose)
        v.setViewVisibility(R.id.widget_awake, if (asleep) View.GONE else View.VISIBLE)
        v.setViewVisibility(R.id.widget_asleep, if (asleep) View.VISIBLE else View.GONE)

        fun put(slot: Int, text: String?, font: String, dp: Float, color: Long, wrapDp: Int? = null, lines: Int = 2) {
            if (text.isNullOrEmpty()) {
                v.setViewVisibility(slot, View.GONE)
                return
            }
            v.setViewVisibility(slot, View.VISIBLE)
            if (style == WidgetStyle.PLAIN) {
                v.setTextViewText(slot, text)
                return
            }
            if (text == HIDDEN) {
                v.setImageViewBitmap(slot, Pixels.hidden(context, dp, color.toInt(), style.bar))
                v.setContentDescription(slot, hiddenLabel ?: context.getString(R.string.balance_widget_hidden))
            } else {
                v.setImageViewBitmap(slot, Pixels.text(context, text, font, dp, color.toInt(), style.bold, wrapDp, lines))
                v.setContentDescription(slot, text)
            }
        }

        val prompt = when {
            w == null -> context.getString(R.string.balance_widget_open)
            choose -> w["label"] as String
            else -> null
        }
        if (prompt != null) {
            // One message in the amount's colour, where the hint goes.
            for (slot in intArrayOf(R.id.widget_label, R.id.widget_amount, R.id.widget_label2, R.id.widget_amount2)) v.setViewVisibility(slot, View.GONE)
            put(R.id.widget_hint, prompt, style.labelFont, style.labelDp + 2f, style.amountColor, style.hintWidthDp)
        } else {
            put(R.id.widget_label, w!!["label"] as String, style.labelFont, style.labelDp, style.labelColor)
            put(R.id.widget_amount, w["amount"] as String, style.amountFont, style.amountDp, style.amountColor)
            put(R.id.widget_label2, w["label2"] as String?, style.labelFont, style.labelDp, style.labelColor)
            put(R.id.widget_amount2, w["amount2"] as String?, style.amountFont, style.amount2Dp, style.amount2Color)
            put(R.id.widget_hint, w["hint"] as String?, style.labelFont, style.hintDp, style.labelColor, style.hintWidthDp, style.hintLines)
        }

        val brand = overview && style.brandDp > 0
        put(R.id.widget_brand, if (brand) "Pocket Sense" else null, "silkscreen", style.brandDp, style.brandColor)
        val stamp = overview && style == WidgetStyle.RECEIPT && w != null && w["hidden"] == true
        v.setViewVisibility(R.id.widget_stamp, if (stamp) View.VISIBLE else View.GONE)
        if (stamp) {
            val word = stampWord ?: context.getString(R.string.balance_widget_stamp)
            v.setImageViewBitmap(R.id.widget_stamp, Pixels.stamp(context, word))
            v.setContentDescription(R.id.widget_stamp, word)
        }

        // The app's language, which can differ from the phone's.
        if (rtl != null) v.setInt(android.R.id.background, "setLayoutDirection", if (rtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR)
        v.setOnClickPendingIntent(android.R.id.background, if (choose) choose(context, id) else open(context))
        return v
    }

    private fun open(context: Context): PendingIntent = PendingIntent.getActivity(
        context,
        0,
        Intent(context, MainActivity::class.java)
            .setAction(Intent.ACTION_MAIN)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    // Its own PendingIntent per widget: they differ only by the extra, which
    // doesn't tell PendingIntents apart, so the widget id is the request code.
    private fun choose(context: Context, widgetId: Int): PendingIntent = PendingIntent.getActivity(
        context,
        widgetId,
        Intent(context, MainActivity::class.java)
            .setAction(ACTION_CHOOSE_ACCOUNT)
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )
}

// Widgets can't use an app's fonts: Android inflates them in a restricted
// context, where TextView ignores android:fontFamily resources. So the text
// is drawn here, into bitmaps at the screen's density. Letters a pixel font
// lacks (Arabic) fall back to the system's.
internal object Pixels {
    private val fonts = HashMap<String, Typeface>()

    private fun font(context: Context, name: String) =
        fonts.getOrPut(name) { Typeface.createFromAsset(context.assets, "fonts/$name.ttf") }

    private fun paint(context: Context, font: String, dp: Float, color: Int, bold: Boolean) =
        TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = font(context, font)
            textSize = dp * context.resources.displayMetrics.density
            this.color = color
            // Pixelify Sans is a variable font; older Android shows its regular weight.
            if (bold && Build.VERSION.SDK_INT >= 26) fontVariationSettings = "'wght' 700"
        }

    // One line, or with wrapDp up to [lines] lines that wide. Bidi and Arabic
    // shaping come from StaticLayout.
    fun text(context: Context, s: String, font: String, dp: Float, color: Int, bold: Boolean, wrapDp: Int? = null, lines: Int = 2): Bitmap {
        val p = paint(context, font, dp, color, bold)
        val natural = ceil(Layout.getDesiredWidth(s, p)).toInt().coerceAtLeast(1)
        val width = wrapDp?.let { minOf(natural, (it * context.resources.displayMetrics.density).toInt()) } ?: natural
        val layout = StaticLayout.Builder.obtain(s, 0, s.length, p, width)
            .setIncludePad(false)
            .setMaxLines(if (wrapDp == null) 1 else lines)
            .setEllipsize(TextUtils.TruncateAt.END)
            .build()
        return Bitmap.createBitmap(width, layout.height.coerceAtLeast(1), Bitmap.Config.ARGB_8888).also { layout.draw(Canvas(it)) }
    }

    // A hidden amount: three pixel squares, or a receipt's black bar. A line tall.
    fun hidden(context: Context, dp: Float, color: Int, bar: Boolean): Bitmap {
        val px = dp * context.resources.displayMetrics.density
        val p = Paint().apply { this.color = color }
        val h = ceil(px).toInt()
        if (bar) {
            val bmp = Bitmap.createBitmap(ceil(px * 4.5f).toInt(), h, Bitmap.Config.ARGB_8888)
            Canvas(bmp).drawRect(0f, h * 0.2f, bmp.width.toFloat(), h * 0.8f, p)
            return bmp
        }
        val side = px * 0.3f
        val gap = side * 0.8f
        val bmp = Bitmap.createBitmap(ceil(side * 3 + gap * 2).toInt(), h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val top = (h - side) / 2
        for (i in 0 until 3) c.drawRect(i * (side + gap), top, i * (side + gap) + side, top + side, p)
        return bmp
    }

    // The receipt's rubber stamp over blacked-out amounts, tilted like a real one.
    fun stamp(context: Context, word: String): Bitmap {
        val d = context.resources.displayMetrics.density
        val ink = 0xFFB3261E.toInt()
        val text = paint(context, "silkscreen", 13f, ink, false)
        val pad = 8 * d
        val w = text.measureText(word) + pad * 2
        val h = 13 * d + pad * 1.4f
        val size = ceil(hypot(w, h)).toInt() + 2
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        c.rotate(-12f, size / 2f, size / 2f)
        val box = RectF((size - w) / 2, (size - h) / 2, (size + w) / 2, (size + h) / 2)
        c.drawRoundRect(box, 6 * d, 6 * d, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xC0F3EEE4.toInt() })
        c.drawRoundRect(box, 6 * d, 6 * d, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = ink
            style = Paint.Style.STROKE
            strokeWidth = 2.5f * d
        })
        val fm = text.fontMetrics
        c.drawText(word, box.left + pad, box.centerY() - (fm.ascent + fm.descent) / 2, text)
        return bmp
    }
}

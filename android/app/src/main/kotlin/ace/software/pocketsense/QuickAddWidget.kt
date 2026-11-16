package ace.software.pocketsense

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

// Home-screen widget: three buttons that open the app on a new expense,
// income, or voice entry, in the look Settings → Widget style picks. It shows
// no amounts: those live in the encrypted database, behind the app lock, and
// stay there.
class QuickAddWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        manager.updateAppWidget(ids, views(context, BalanceWidgets.savedStyle(context)))
    }

    companion object {
        // When the style changes (BalanceWidgets.show).
        fun restyle(context: Context, style: WidgetStyle) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, QuickAddWidget::class.java))
            if (ids.isNotEmpty()) manager.updateAppWidget(ids, views(context, style))
        }

        private fun views(context: Context, style: WidgetStyle) = RemoteViews(context.packageName, style.quickAddLayout).apply {
            setOnClickPendingIntent(R.id.quick_add_expense, open(context, MainActivity.ACTION_ADD_EXPENSE))
            setOnClickPendingIntent(R.id.quick_add_income, open(context, MainActivity.ACTION_ADD_INCOME))
            setOnClickPendingIntent(R.id.quick_add_voice, open(context, MainActivity.ACTION_ADD_VOICE))
            // The app's words and direction once it has run; the phone's before.
            val prefs = BalanceWidgets.prefs(context)
            fun word(key: String, fallback: Int) = prefs.getString(key, null) ?: context.getString(fallback)
            if (prefs.contains("rtl")) {
                setInt(android.R.id.background, "setLayoutDirection", if (prefs.getBoolean("rtl", false)) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR)
            }
            setContentDescription(R.id.quick_add_voice, word("voice", R.string.quick_add_voice))
            for ((label, text, words, color) in listOf(
                Label(R.id.qa_expense_label, R.id.qa_expense_text, word("expense", R.string.quick_add_expense), style.quickAddExpense),
                Label(R.id.qa_income_label, R.id.qa_income_text, word("income", R.string.quick_add_income), style.quickAddIncome),
            )) {
                setTextViewText(text, words)
                // The pixel styles draw their labels (widgets can't use an app's
                // fonts); the TextView underneath is for Plain and the picker's preview.
                val font = style.quickAddFont ?: continue
                setImageViewBitmap(label, Pixels.text(context, words, font, style.quickAddDp, color.toInt(), style.bold))
                setContentDescription(label, words)
                setViewVisibility(label, View.VISIBLE)
                setViewVisibility(text, View.GONE)
            }
        }

        private data class Label(val image: Int, val text: Int, val words: String, val color: Long)

        // Each action is its own PendingIntent (they differ by action), and goes
        // to the running app if there is one (singleTop → onNewIntent).
        private fun open(context: Context, action: String): PendingIntent = PendingIntent.getActivity(
            context,
            action.hashCode(),
            Intent(context, MainActivity::class.java)
                .setAction(action)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }
}

package ace.software.pocketsense

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

// Home-screen widget: three buttons that open the app on a new expense,
// income, or voice entry. It shows no amounts: those live in the encrypted
// database, behind the app lock, and stay there.
class QuickAddWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val views = RemoteViews(context.packageName, R.layout.quick_add_widget).apply {
            setOnClickPendingIntent(R.id.quick_add_expense, open(context, MainActivity.ACTION_ADD_EXPENSE))
            setOnClickPendingIntent(R.id.quick_add_income, open(context, MainActivity.ACTION_ADD_INCOME))
            setOnClickPendingIntent(R.id.quick_add_voice, open(context, MainActivity.ACTION_ADD_VOICE))
        }
        manager.updateAppWidget(ids, views)
    }

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

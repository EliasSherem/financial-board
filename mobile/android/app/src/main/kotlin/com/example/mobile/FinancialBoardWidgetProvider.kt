package com.example.mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class FinancialBoardWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    for (widgetId in appWidgetIds) {
      val views = RemoteViews(context.packageName, R.layout.widget_quick_transaction)
      val palette = WidgetPalette.from(context, widgetData)

      val amount =
          widgetData
              .getString(
                  KEY_DISPLAY_VALUE, context.getString(R.string.widget_default_amount))
              ?: context.getString(R.string.widget_default_amount)
      val monthLabel =
          widgetData
              .getString(
                  KEY_MONTH_LABEL, context.getString(R.string.widget_default_month))
              ?: context.getString(R.string.widget_default_month)

      views.setTextViewText(R.id.widget_amount, amount)
      views.setTextViewText(R.id.widget_month_label, monthLabel)
      views.applyPalette(palette)

      val launchIntent =
          HomeWidgetLaunchIntent.getActivity(
              context,
              MainActivity::class.java,
              Uri.parse("financialboard://widget/$ACTION_CREATE_TRANSACTION"),
          )
      val scanReceiptIntent =
          HomeWidgetLaunchIntent.getActivity(
              context,
              MainActivity::class.java,
              Uri.parse("financialboard://widget/$ACTION_SCAN_RECEIPT"),
          )
      views.setOnClickPendingIntent(R.id.widget_action_container, launchIntent)
      views.setOnClickPendingIntent(R.id.widget_recurring_container, scanReceiptIntent)
      views.setOnClickPendingIntent(R.id.widget_root, launchIntent)

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }

  companion object {
    private const val ACTION_CREATE_TRANSACTION = "create-transaction"
    private const val ACTION_SCAN_RECEIPT = "scan-receipt"
    private const val KEY_DISPLAY_VALUE = "kpi_spent_display"
    private const val KEY_MONTH_LABEL = "kpi_spent_month_label"
    private const val KEY_THEME_MODE = "widget_theme_mode"
  }

  private data class WidgetPalette(
      val isDark: Boolean,
      val primary: Int,
      val primaryText: Int,
      val secondaryText: Int,
  ) {
    val rootBackground: Int =
        if (isDark) R.drawable.widget_background_dark else R.drawable.widget_background_light
    val cardBackground: Int =
        if (isDark) R.drawable.widget_card_background_dark else R.drawable.widget_card_background_light
    val buttonBackground: Int =
        if (isDark) R.drawable.widget_button_background_dark else R.drawable.widget_button_background_light

    companion object {
      fun from(context: Context, widgetData: SharedPreferences): WidgetPalette {
        val configuredMode = widgetData.getString(KEY_THEME_MODE, "system") ?: "system"
        val systemIsDark =
            (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
        val isDark =
            when (configuredMode) {
              "dark" -> true
              "light" -> false
              else -> systemIsDark
            }

        return if (isDark) {
          WidgetPalette(
              isDark = true,
              primary = Color.rgb(96, 165, 250),
              primaryText = Color.rgb(248, 250, 252),
              secondaryText = Color.rgb(182, 194, 210),
          )
        } else {
          WidgetPalette(
              isDark = false,
              primary = Color.rgb(37, 99, 235),
              primaryText = Color.rgb(17, 24, 39),
              secondaryText = Color.rgb(100, 116, 139),
          )
        }
      }
    }
  }

  private fun RemoteViews.applyPalette(palette: WidgetPalette) {
    setInt(R.id.widget_root, "setBackgroundResource", palette.rootBackground)
    setInt(R.id.widget_card, "setBackgroundResource", palette.cardBackground)
    setInt(R.id.widget_action_container, "setBackgroundResource", palette.buttonBackground)
    setInt(R.id.widget_recurring_container, "setBackgroundResource", palette.buttonBackground)

    setTextColor(R.id.widget_title, palette.secondaryText)
    setTextColor(R.id.widget_amount, palette.primaryText)
    setTextColor(R.id.widget_month_label, palette.secondaryText)
    setTextColor(R.id.widget_action_text, palette.primary)
    setTextColor(R.id.widget_recurring_text, palette.primary)

    setInt(R.id.widget_action_icon, "setColorFilter", palette.primary)
    setInt(R.id.widget_recurring_icon, "setColorFilter", palette.primary)
  }
}

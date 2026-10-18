package com.lumifx.lumifx

import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/**
 * A quick settings tile that opens a lumifx:// link: the app stops the
 * effect or starts bedtime, as from a widget tile or an automation.
 */
abstract class LinkTileService : TileService() {
    abstract val link: String

    override fun onStartListening() {
        qsTile?.apply {
            state = Tile.STATE_ACTIVE
            updateTile()
        }
    }

    override fun onClick() {
        if (isLocked) {
            unlockAndRun { open() }
        } else {
            open()
        }
    }

    private fun open() {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(link), this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(
                PendingIntent.getActivity(
                    this,
                    link.hashCode(),
                    intent,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                ),
            )
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}

class StopTileService : LinkTileService() {
    override val link = "lumifx://app/stop"
}

class BedtimeTileService : LinkTileService() {
    override val link = "lumifx://app/bedtime"
}

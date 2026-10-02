package net.omarmali.splitapp

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingContactPickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CONTACT_PICKER_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickContacts" -> {
                    if (pendingContactPickerResult != null) {
                        result.error("picker_busy", "Contact picker is already open.", null)
                        return@setMethodCallHandler
                    }
                    val selectionLimit = (call.argument<Int>("selectionLimit") ?: 50).coerceIn(1, 100)
                    pendingContactPickerResult = result
                    launchContactPicker(selectionLimit)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun launchContactPicker(selectionLimit: Int) {
        val requestedFields = arrayListOf(
            ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE,
            ContactsContract.CommonDataKinds.Email.CONTENT_ITEM_TYPE,
        )
        val intent = Intent(ACTION_PICK_CONTACTS).apply {
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            putExtra(EXTRA_PICK_CONTACTS_SELECTION_LIMIT, selectionLimit)
            putStringArrayListExtra(EXTRA_PICK_CONTACTS_REQUESTED_DATA_FIELDS, requestedFields)
        }
        val fallbackIntent = Intent(Intent.ACTION_PICK).apply {
            type = ContactsContract.CommonDataKinds.Phone.CONTENT_TYPE
            putExtra(EXTRA_USE_SYSTEM_CONTACTS_PICKER, true)
        }

        try {
            when {
                intent.resolveActivity(packageManager) != null -> {
                    startActivityForResult(intent, REQUEST_PICK_CONTACTS)
                }
                fallbackIntent.resolveActivity(packageManager) != null -> {
                    startActivityForResult(fallbackIntent, REQUEST_PICK_CONTACTS)
                }
                else -> {
                    completeContactPickerError("picker_unavailable", "No contact picker is available.")
                }
            }
        } catch (error: Exception) {
            completeContactPickerError("picker_failed", error.localizedMessage ?: "Could not open contacts.")
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_PICK_CONTACTS) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }

        if (resultCode != Activity.RESULT_OK || data == null) {
            completeContactPicker(emptyList())
            return
        }

        try {
            completeContactPicker(readPickedContacts(data))
        } catch (error: Exception) {
            completeContactPickerError(
                "picker_read_failed",
                error.localizedMessage ?: "Could not read selected contacts."
            )
        }
    }

    private fun readPickedContacts(data: Intent): List<Map<String, Any>> {
        val contacts = linkedMapOf<String, PickedContact>()
        val sessionUri = data.data
        if (sessionUri != null && sessionUri.authority == CONTACT_PICKER_AUTHORITY) {
            readSessionContacts(sessionUri, contacts)
            return contacts.values.map { it.toMap() }
        }

        data.clipData?.let { clipData ->
            for (index in 0 until clipData.itemCount) {
                clipData.getItemAt(index).uri?.let { readLegacyPhoneContact(it, contacts) }
            }
        }
        sessionUri?.let { readLegacyPhoneContact(it, contacts) }
        return contacts.values.map { it.toMap() }
    }

    private fun readSessionContacts(uri: Uri, contacts: MutableMap<String, PickedContact>) {
        val projection = arrayOf(
            ContactsContract.Data.LOOKUP_KEY,
            ContactsContract.Data.DISPLAY_NAME_PRIMARY,
            ContactsContract.Data.MIMETYPE,
            ContactsContract.Data.DATA1,
        )
        contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
            val lookupKeyIndex = cursor.getColumnIndex(ContactsContract.Data.LOOKUP_KEY)
            val nameIndex = cursor.getColumnIndex(ContactsContract.Data.DISPLAY_NAME_PRIMARY)
            val mimeTypeIndex = cursor.getColumnIndex(ContactsContract.Data.MIMETYPE)
            val dataIndex = cursor.getColumnIndex(ContactsContract.Data.DATA1)

            while (cursor.moveToNext()) {
                val lookupKey = cursor.getStringOrEmpty(lookupKeyIndex)
                if (lookupKey.isBlank()) continue
                val contact = contacts.getOrPut(lookupKey) {
                    PickedContact(
                        id = lookupKey,
                        displayName = cursor.getStringOrEmpty(nameIndex),
                    )
                }
                when (cursor.getStringOrEmpty(mimeTypeIndex)) {
                    ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE -> {
                        contact.addPhone(cursor.getStringOrEmpty(dataIndex))
                    }
                    ContactsContract.CommonDataKinds.Email.CONTENT_ITEM_TYPE -> {
                        contact.addEmail(cursor.getStringOrEmpty(dataIndex))
                    }
                }
            }
        }
    }

    private fun readLegacyPhoneContact(uri: Uri, contacts: MutableMap<String, PickedContact>) {
        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME_PRIMARY,
            ContactsContract.CommonDataKinds.Phone.NUMBER,
            ContactsContract.CommonDataKinds.Phone.NORMALIZED_NUMBER,
        )
        contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
            if (!cursor.moveToFirst()) return
            val id = cursor.getStringOrEmpty(
                cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.CONTACT_ID)
            ).ifBlank { uri.toString() }
            val contact = contacts.getOrPut(id) {
                PickedContact(
                    id = id,
                    displayName = cursor.getStringOrEmpty(
                        cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME_PRIMARY)
                    ),
                )
            }
            contact.addPhone(
                cursor.getStringOrEmpty(
                    cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NORMALIZED_NUMBER)
                ).ifBlank {
                    cursor.getStringOrEmpty(
                        cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                    )
                }
            )
        }
    }

    private fun android.database.Cursor.getStringOrEmpty(index: Int): String {
        return if (index >= 0 && !isNull(index)) getString(index) ?: "" else ""
    }

    private fun completeContactPicker(contacts: List<Map<String, Any>>) {
        pendingContactPickerResult?.success(contacts)
        pendingContactPickerResult = null
    }

    private fun completeContactPickerError(code: String, message: String) {
        pendingContactPickerResult?.error(code, message, null)
        pendingContactPickerResult = null
    }

    private data class PickedContact(
        val id: String,
        val displayName: String,
        val phones: MutableList<String> = mutableListOf(),
        val emails: MutableList<String> = mutableListOf(),
    ) {
        fun addPhone(value: String) {
            val phone = value.trim()
            if (phone.isNotEmpty() && !phones.contains(phone)) {
                phones.add(phone)
            }
        }

        fun addEmail(value: String) {
            val email = value.trim()
            if (email.isNotEmpty() && !emails.contains(email)) {
                emails.add(email)
            }
        }

        fun toMap(): Map<String, Any> = mapOf(
            "id" to id,
            "displayName" to displayName,
            "phones" to phones,
            "emails" to emails,
        )
    }

    companion object {
        private const val CONTACT_PICKER_CHANNEL = "net.omarmali.splitapp/contact_picker"
        private const val REQUEST_PICK_CONTACTS = 7319
        private const val ACTION_PICK_CONTACTS = "android.provider.action.PICK_CONTACTS"
        private const val CONTACT_PICKER_AUTHORITY = "com.android.contacts.picker.sessions"
        private const val EXTRA_PICK_CONTACTS_REQUESTED_DATA_FIELDS =
            "android.provider.extra.PICK_CONTACTS_REQUESTED_DATA_FIELDS"
        private const val EXTRA_PICK_CONTACTS_SELECTION_LIMIT =
            "android.provider.extra.PICK_CONTACTS_SELECTION_LIMIT"
        private const val EXTRA_USE_SYSTEM_CONTACTS_PICKER =
            "android.intent.extra.USE_SYSTEM_CONTACTS_PICKER"
    }
}

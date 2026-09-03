# Privacy

Metasequoia IME for macOS processes keystrokes, pre-edit text, and candidates locally on the user's Mac. The application does not send typed text, candidates, learned words, preferences, diagnostics, analytics, or crash reports over the network. It does not include a network service or cloud synchronization feature.

The input method stores its settings in the current user's macOS preferences. When candidate learning is enabled, learned word-frequency changes are stored locally under `~/Library/Application Support/metasequoiaime/`. The bundled dictionary is copied to the same directory so it can be upgraded safely. These files are available only through the permissions of the local macOS account; users should protect that account and its backups as they would other personal data.

The settings panel can disable candidate learning and can erase learned input data. If learning is disabled while a composition is active, that composition keeps the setting it started with; after it is committed or cancelled, newly started compositions do not update word frequencies. Erasing learned data removes the local learning databases and restores the bundled dictionary without deleting unrelated preferences.

Metasequoia IME does not sell or share personal data. Installing or using the software does not create an account. If a future release adds any network-backed feature, this notice must be updated before that feature is shipped.

Security or privacy concerns should be reported privately as described in [SECURITY.md](SECURITY.md).

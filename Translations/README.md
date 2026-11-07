# Phosprite UI localization

The **single application text catalog** is `Translations/Translations.pot`.
Translations live beside it in `Translations/<locale>.po`. The English source
text (Gettext `msgid`) is the fallback if a locale has no translation.

Phosprite inherits existing Pixelorama translations. Phosprite-specific interface
strings, including iPad project gallery, workspaces, menus, tool options and
timeline features, must be maintained in this directory rather than in separate
hard-coded Chinese/English branches.

## Adding interface text

1. Write a stable English source message. In `.tscn` controls use standard text
   properties; in GDScript use `tr("English text")` for computed or formatted
   messages. Avoid combining several translatable fragments.
2. Add the exact English message to `Translations/Translations.pot`.
3. Add its translation to `Translations/zh_CN.po` and `zh_TW.po`. Preserve
   `%s`, `%d`, `{name}`, and newline placeholders. Missing translations
   remain in English rather than silently using another language.
4. When adding more supported languages, update their PO files by merging the
   current POT template (for example using `msgmerge` or Poedit).
5. Verify in the app with English, Simplified Chinese and Traditional Chinese,
   including switching language while dialogs and the timeline are visible.

The bundled Keychain add-on still includes its upstream translation directory,
but shared app terms and the missing Chinese Keychain messages are covered by
the main application catalog. Avoid adding a second competing Chinese catalog
for the same messages.

Upstream Pixelorama translations can still be contributed via
[Pixelorama Crowdin](https://crowdin.com/project/pixelorama). Phosprite-specific
translations should be updated in this repository.

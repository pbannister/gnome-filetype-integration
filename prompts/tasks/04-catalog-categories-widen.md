# Task: Widen the catalog in the least-covered categories

## TASK-DESCRIPTION
- Modify: `tests/30-application-catalog.sh`
- Modify: `sources/filetype_integration/data/application-catalog.json`
- Modify: `site.in/index.txt`
- Modify: `README.md`
- Modify: `documents/11-application-catalog.md`
- Modify: `documents/12-data-sources.md`
- Modify: `prompts/tasks/00-tasks.md`
- Modify: `TODO.md`

Widen the curated catalog from 189 to 210 applications, starting with the
least-covered categories: presentation, calendar, contact, subtitle.
Add the 21 entries and the three handle extensions listed in TASK-CONTEXT,
each with a purpose sentence and the schema's required fields.

Test first: add the section 4.6 assertions to `tests/30-application-catalog.sh`,
run that test, and confirm it fails against the current catalog before
changing the data.
The catalog data is the only behavior change; identifier, ranking, and
chooser code stay untouched.

`site.in/index.txt` hardcodes "169 applications"; replace the number with the
`__CATALOG_APPLICATIONS__` placeholder so the page stops drifting.
`README.md` states the catalog has 189 applications; update the count to 210.
The two data documents date the package-name check 2026-10-22; extend each
date clause with the 2026-11-20 re-check of the widened categories.
`prompts/tasks/00-tasks.md`: index this task file.
`TODO.md`: mark the widen item complete after verification succeeds.

Rebuild and republish the page set so the published read interface stays
current: `make build`, `make state`, `make site`, `make check` on this host,
then the homelab's `make deploy` from `~/work/00-homelab`. No registry change
this time; the registration already exists.

## TASK-OUTPUT
* Report the entries added, the catalog validate result, the test result,
  and the gate, deploy, and curl results.
* End with the `VERIFICATION:` line.

## TASK-CONTEXT
<note>
The catalog schema and the estimate scales are in
`documents/11-application-catalog.md`. Install hints were checked on
Ubuntu 26.04 (apt candidates), Flathub (application IDs), and the project
homepages (HTTP 200) on 2026-11-20. Popularity and maturity are editorial
estimates per that document; the values below are the task's decision.
</note>
<constraint>
Write the test assertions before the catalog data and show the pre-change
failure. Change no executable source code. Leave `records/` untouched: the
counts there are historical facts. The homelab deploy is the only publisher;
before it, confirm the homelab working tree is clean, and do not push either
repository to its remote. Rollback for the publish: revert the catalog
commit, rebuild, and redeploy. If the leak gate or the deploy refuses, stop
and report.
</constraint>
<task_context>
Handle extensions to existing entries:
- org.libreoffice.LibreOffice: add the PowerPoint MIME set (below), the ODP
  template and flat-XML MIME types, and extensions ppt, pps, pot, ppz, pptx,
  ppsx, potx, pptm, ppsm, potm, sldx, sldm, ppam.
- org.onlyoffice.desktopeditors: add application/vnd.ms-powerpoint, the three
  macro-enabled PowerPoint MIME types, and the presentationml presentation,
  slideshow, and template MIME types; extensions ppt, pps, pot, pptx, ppsx,
  potx, pptm, ppsm, potm.
- aegisub: add MIME application/x-subrip.

PowerPoint MIME set: application/vnd.ms-powerpoint,
application/vnd.ms-powerpoint.addin.macroenabled.12,
application/vnd.ms-powerpoint.presentation.macroenabled.12,
application/vnd.ms-powerpoint.slide.macroenabled.12,
application/vnd.ms-powerpoint.slideshow.macroenabled.12,
application/vnd.ms-powerpoint.template.macroenabled.12,
application/vnd.openxmlformats-officedocument.presentationml.presentation,
application/vnd.openxmlformats-officedocument.presentationml.slide,
application/vnd.openxmlformats-officedocument.presentationml.slideshow,
application/vnd.openxmlformats-officedocument.presentationml.template.

New entries (id — name; kind, maturity, popularity, usefulness; install;
handles; homepage):

presentation:
- org.kde.calligra — Calligra Stage; gui, stable, 25, general; apt calligra,
  flatpak org.kde.calligra; MIME ms-powerpoint, presentationml.presentation,
  oasis odp; ext ppt, pptx, odp; cat presentation; https://calligra.org/.
- freeoffice — FreeOffice Presentations; gui, mature, 40, general;
  url https://www.freeoffice.com/; MIME ms-powerpoint,
  presentationml.presentation, oasis odp; ext ppt, pptx, pps, ppsx, odp;
  cat presentation; homepage same as the url.
- wps-office — WPS Office; gui, mature, 55, general;
  url https://www.wps.com/; handles as FreeOffice; homepage same as the url.
- impressive — Impressive; gui, stable, 15, specialized; apt impressive;
  MIME application/pdf; cat presentation;
  https://sourceforge.net/projects/impressive/.
- pdfpc — PDF Presenter Console; gui, stable, 15, specialized;
  apt pdf-presenter-console; MIME application/pdf; cat presentation;
  https://pdfpc.github.io/; about https://github.com/pdfpc/pdfpc;
  binary pdfpc.

calendar:
- khal — khal; cli, stable, 20, primary; apt khal; MIME text/calendar,
  text/x-vcalendar; ext ics, ifb, vcs; cat calendar;
  https://github.com/pimutils/khal; binary khal.
- org.kde.korganizer — KOrganizer; gui, mature, 35, primary; apt korganizer;
  handles as khal; https://userbase.kde.org/KOrganizer.
- net.sourceforge.osmo — Osmo; gui, stable, 10, general; apt osmo,
  flatpak net.sourceforge.osmo; MIME text/calendar, text/vcard; ext ics, vcf;
  cat calendar, contact; http://osmo-pim.sourceforge.net/.
- gcalcli — gcalcli; cli, stable, 20, companion; apt gcalcli;
  MIME text/calendar; ext ics; cat calendar;
  https://github.com/insanum/gcalcli; binary gcalcli.
- vdirsyncer — vdirsyncer; cli, stable, 15, companion; apt vdirsyncer;
  MIME text/calendar, text/vcard; ext ics, vcf; cat calendar, contact;
  https://github.com/pimutils/vdirsyncer; binary vdirsyncer.
- python3-icalendar — icalendar (Python); cli, stable, 15, companion;
  apt python3-icalendar; MIME text/calendar; ext ics; cat calendar;
  https://github.com/collective/icalendar.

contact:
- org.kde.kaddressbook — KAddressBook; gui, mature, 30, primary;
  apt kaddressbook; MIME text/vcard; ext vcf, vcard; cat contact;
  https://userbase.kde.org/KAddressBook.
- khard — khard; cli, stable, 15, primary; apt khard; MIME text/vcard;
  ext vcf, vcard; cat contact; https://github.com/lucc/khard;
  about https://khard.readthedocs.io/; binary khard.
- abook — abook; cli, legacy, 10, general; apt abook; MIME text/vcard;
  ext vcf; cat contact; http://abook.sourceforge.net/; binary abook.
- python3-vobject — vobject (Python); cli, stable, 10, companion;
  apt python3-vobject; MIME text/vcard, text/calendar; ext vcf, ics;
  cat contact, calendar; https://github.com/eventable/vobject.

subtitle:
- org.kde.subtitlecomposer — Subtitle Composer; gui, stable, 20, primary;
  apt subtitlecomposer, flatpak org.kde.subtitlecomposer;
  MIME application/x-subrip, application/ttml+xml, text/vtt;
  ext srt, ass, ssa, sub, vtt, ttml; cat subtitle;
  https://subtitlecomposer.kde.org/.
- gaupol — Gaupol; gui, stable, 15, primary; apt gaupol; handles as
  Subtitle Composer; https://github.com/otsaloma/gaupol.
- subtitle-edit — Subtitle Edit; gui, mature, 45, primary;
  url https://github.com/SubtitleEdit/subtitleedit; handles as
  Subtitle Composer; homepage same as the url; notes: the Linux build is a
  portable .NET archive.
- subliminal — subliminal; cli, stable, 20, companion; apt subliminal;
  MIME application/x-subrip; ext srt, ass, ssa, sub, vtt; cat subtitle;
  https://github.com/Diaoul/subliminal; binary subliminal.
- python3-srt — srt (Python); cli, stable, 10, companion; apt python3-srt;
  MIME application/x-subrip; ext srt; cat subtitle;
  https://github.com/byroot/pysrt.
- ffsubsync — ffsubsync; cli, stable, 15, companion;
  url https://github.com/smacke/ffsubsync; MIME application/x-subrip;
  ext srt, ass, ssa, sub, vtt; cat subtitle; homepage same as the url;
  binary ffsubsync; notes: install with pip.

Every new entry carries a one-sentence purpose written for someone who does
not know the project. CLI entries are libraries or tools; the Python
libraries follow the existing "pkpass (Python)" naming.

Test assertions (new section 4.6, using catalog.matches as section 2 does):
- pptx (presentationml.presentation, ext pptx, cat presentation) matches
  org.libreoffice.LibreOffice with match_score >= 100.
- text/calendar (ext ics, cat calendar) matches khal with match_score >= 100.
- text/vcard (ext vcf, cat contact) matches khard with match_score >= 100.
- application/x-subrip (ext srt, cat subtitle) matches
  org.kde.subtitlecomposer with match_score >= 100.
</task_context>

## TASK-FILES

| Operation | Path |
|---|---|
| modify | `tests/30-application-catalog.sh` |
| modify | `sources/filetype_integration/data/application-catalog.json` |
| modify | `site.in/index.txt` |
| modify | `README.md` |
| modify | `documents/11-application-catalog.md` |
| modify | `documents/12-data-sources.md` |
| modify | `prompts/tasks/00-tasks.md` |
| modify | `TODO.md` |

## TASK-VERIFY
- Run: `sh tests/30-application-catalog.sh` before the data change.
- Expected: nonzero exit, the new section 4.6 assertion failing.
- Run: `make test` from the repository root.
- Expected: exit status 0.
- Run: `dataflow.out/build/program/bin/filetype catalog validate`.
- Expected: exit status 0.
- Run: `make build && make state && make site && make check`.
- Expected: exit status 0, `leak-gate: clean: site.out`, and the catalog report naming 210 applications.
- Run: `make deploy` from `~/work/00-homelab`.
- Expected: exit status 0, with this project's pages staged and the rsync reported.
- Run: `curl -fsS https://labs.bannister.us/projects/gnome-filetype-integration/`.
- Expected: HTTP 200, the one homelab nav, and the catalog count 210 on the index page.

## TASK-FEATURES
- `prompts/features/03-file-type-integration.md`
- `prompts/features/02-project-pages.md`

## TASK-ACCEPTANCE
- `FILETYPE-R006`
- `FILETYPE-R008`
- `FILETYPE-R038`
- `PROJECT-PAGES-R012`
- `PROJECT-PAGES-R017`

OUTPUT: the entries added, the validate, test, gate, deploy, and curl results, ending with the `VERIFICATION:` line.
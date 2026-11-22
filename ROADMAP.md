# HobbyAtlas Roadmap

HobbyAtlas is free and open source (MIT), and every feature is included for everyone. If the project needs funding later, the options are GitHub Sponsors, Open Collective or optional donations. Features will never be locked.

## Done: v1
Custom boards, materials lists with costs, photo progress timeline with before/after, built-in hobby templates, notes, and unlimited projects.

## Next: Hobby templates
- **Template library**: many more templates per hobby, such as a seed-starting calendar, Gundam kit, PCB build, dovetail box or coin grading log. Templates are plain data in `Templates.swift`, so they're easy for contributors to add.
- **Save any project as a template**, with import/export as a `.hobbyatlas-template` file you can share.
- **Custom fields per hobby**: scale and kit number (models), plant variety and sow/harvest dates (garden), part numbers and datasheet links (electronics), wood species and dimensions (woodworking), condition, grade and value (collections).
- **Community template repo**: a GitHub repository of templates the app can browse and import.

## Then: Creator community
- **Public build logs**: export a project as a static web page (photos, steps, materials) to host anywhere, for example GitHub Pages.
- **Template gallery** fed by the community repo, with remix-into-my-library.
- **Challenges and build-alongs** with shared templates.

## More feature ideas
1. **iPhone/iPad companion with iCloud sync.** Take photos at the bench or in the garden and they appear in the project timeline.
2. **Inventory / stash tracker** across projects (paints, filament, lumber offcuts, seeds, components), linked to materials lists.
3. **Time tracking**: start/stop timer per card, plus hours-per-project stats.
4. **Reminders and seasonal schedules**: watering, cure and dry times, tool maintenance (local notifications).
5. **Tools and equipment register** with manuals, warranty dates and maintenance logs.
6. **Wishlist** for kits and parts you want.
7. **Auto timelapse and progress reel** made from the photo timeline.
8. **Export and backup**: PDF build log, CSV of materials and spending, Markdown, full backup/restore.
9. **Spending dashboard**: money spent per hobby per year, and cost per finished project.
10. **Barcode / QR scanning** (on iPhone), and printable QR labels for storage bins.
11. **Hobby-specific tools**: garden bed planner and frost dates, woodworking cut-list optimizer and board-foot calculator, electronics BOM import (KiCad/CSV) and calculators, collector grading and value reports, paint-mix recipes for modelers.
12. **Optional AI assist** using the user's own API key: plan a project from a description, identify plants or parts from a photo.
13. **Localization** into more languages.

## Suggested order
1. iPhone companion + iCloud sync
2. Template library, save-as-template, community template repo
3. Inventory/stash + reminders
4. Export/backup + spending dashboard
5. Public build logs
6. Hobby-specific tools

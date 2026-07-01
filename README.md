# 🧑‍💻 FiveM Advanced Multicharacter & Character Creator

A complete, production-ready **Multicharacter Selection** and **Character Identity/Appearance Creator** system built for FiveM. This resource features a modern, responsive NUI interface (HTML5/CSS3/JS), precise physical feature morphing, strict character limit validation, and an interactive identity card (`/dowod`) system.

---

## 🚀 Key Features

* **Cinematic Multicharacter Hub:** Upon connecting, players are placed into a custom camera sequence (cinematic view). Player control is fully locked (`SetNuiFocus`), and the user is presented with up to 3 character slots.
* **Comprehensive Registration Form:** Strict client and server-side validation for:
    * First & Last Name (with custom regex filters).
    * Nationality / Origin.
    * Date of Birth (formatted calendar/input).
    * Height limits enforced strictly between **150 cm** and **200 cm**.
    * Gender selection that dynamically swaps the base multiplayer ped models (`mp_m_freemode_01` / `mp_f_freemode_01`).
* **Granular Appearance Customization:** 
    * **Heritage & Shape:** Blending parent faces and skin tones dynamically.
    * **Barber Options:** Haircuts, hair color, highlights, eyebrows, facial hair, chest hair, and makeup options.
    * **Physical Details:** Eye color, skin blemishes, aging, and complexion.
    * **Starting Outfits:** Easy clothing selection (shirts, pants, shoes) to prevent spawning invisible or naked.
* **Interactive ID Card (`/dowod`):** An aesthetic, fully styled physical identification card widget rendered via UI. Displays full character details, an automatic gender-based profile silhouette, and syncs to nearby players.
* **Exploit-Safe Architecture:** Server-side validation ensures players cannot spoof data, trigger unauthorized character creation events, or exceed the 3-character slot limit.

---

## 📁 Project Structure

```text
├── client/
│   └── main.lua       # Camera handling, ped manipulation, NUI callbacks, grid system
├── server/
│   └── main.lua       # Database queries, exploit prevention, server commands
├── html/
│   ├── index.html     # Main NUI layout (Selection UI, Creator Wizard, ID Card Component)
│   ├── style.css      # Modern dark-theme UI with smooth animations & transitions
│   └── script.js      # NUI callbacks, input validation, and event handling
├── fxmanifest.lua     # FiveM resource manifest
└── init.sql           # Optimized MySQL database schema
🔗 Contact & Support
If you run into any setup issues, want to request specific features, or would like to report code bugs, feel free to join the official developer communication channels:

GitHub Profile: https://github.com/77nest1

Discord Community: https://www.google.com/search?q=https://discord.gg/R9hDWnFcb4

# Thumbnail shoot, 2026-10-23 (Play, integration 4cb3f30)

Staging (server, ServerStorage.DebugSet): realm 10, lives 101 (100 rebirths = full white-jade band), pass + ride swordCelestial.
Variants: realm/lives 10/101, 9/61 (blue), 8/41 (red), 6/21 (gold) x swordJade/swordHeavenly/swordCelestial.
Avatar (HumanoidDescription): all body colours (242,243,243); HairAccessory 63690008 Pal Hair; Shirt 4047884046 Guitar Tee with Black Jacket; Pants 144076760 Dark Green Jeans; Face 144075659 Smile; BodyTypeScale/ProportionScale 0, zero body part ids.
Rider: HumanoidRootPart anchored (server) at P = (-502.94, 115, 110.78), radius 515 from the hub on the sun's azimuth.
Light: client DayNightOffset set so it is day (NightWeight 0); Lighting.ClockTime held at 16.5 every frame. Sun direction (-0.9053, 0.3750, 0.1994), elevation 22.0 deg.
UI: every PlayerGui LayerCollector off, CoreGui off, Humanoid DisplayDistanceType None.
Camera rig: shotrig.luau (client). The client sets the root CFrame (local only) and a Scriptable camera every frame from _G.shot.
Captures: MCP screen_capture, 1586x896 (the Studio viewport), JPEG from Studio saved as PNG.

| shot | params | camera CFrame | rider CFrame |
|---|---|---|---|
| A1 | az=-25 pitch=15 d=11 fov=50 shiftR=3 yaw=-45 | -493.227753, 112.152992, 116.019714, 0.217776701, 0.252605826, 0.942742646, 0, 0.965926111, -0.258817822, -0.975998521, 0.0563644916, 0.210356236 | -502.944611, 115, 110.777809, -0.844130874, 0, -0.536137283, 0, 1, 0, 0.536137283, 0, -0.844130874 |
| A2 | az=-32 pitch=19 d=10.5 fov=50 shiftR=3.3 yaw=-62 | -494.696503, 111.581535, 117.213844, 0.335102171, 0.306748867, 0.890848935, 0, 0.945517063, -0.325572908, -0.942181826, 0.109100185, 0.316844791 | -502.944611, 115, 110.777809, -0.989217639, 0, -0.146453544, 0, 1, 0, 0.146453559, 0, -0.98921752 |
| A3 | az=-18 pitch=12 d=12.5 fov=45 shiftR=3.4 shiftU=-0.3 yaw=-52 | -491.106171, 112.701111, 115.350258, 0.0972098261, 0.206924975, 0.973515511, 0, 0.978148103, -0.207909644, -0.995263934, 0.0202108603, 0.095085606 | -502.944611, 115, 110.777809, -0.844130874, 0, -0.536137283, 0, 1, 0, 0.536137283, 0, -0.844130874 |
| A_plate | A1, character hidden | as A1 | |
| B1 | az=-15 pitch=8 d=14 fov=40 shiftR=-3.4 yaw=90 speed=60 (5 s loop from P, ~2.5 s in) | moves with the rider | heading (0.13, 0, -0.99) |
| B2 | az=-8 pitch=4 d=14 fov=40 shiftR=-3.4 shiftU=-1.2 yaw=80 speed=60 | -488.410736, 115.223404, 97.3866577, -0.0770918503, 0.0695477501, 0.994595408, 0, 0.997564197, -0.0697553456, -0.997024, -0.00537756877, -0.0769040659 | -502.072937, 115, 101.853218, 0.995265007, 0, -0.097198762, 0, 1, 0, 0.097198762, 0, 0.995265007 |
| B_plate | B1, character hidden | | |
| C1 | az=-4 pitch=14.02 d=14 fov=50 shiftR=-2.2 shiftU=-1.0 yaw=-40 | -489.830566, 112.607353, 106.612274, -0.146452889, 0.239716038, 0.959733248, 0, 0.970194221, -0.242328912, -0.989217639, -0.0354897678, -0.142087758 | -502.944611, 115, 110.777809, -0.523664057, 0, -0.851924837, 0, 1, 0, 0.851924956, 0, -0.523663998 |
| C2 | az=-2 pitch=16.02 d=10.5 fov=50 shiftR=-1.9 shiftU=-1.3 yaw=-30 | -493.362762, 113.401543, 107.083611, -0.180888474, 0.271494806, 0.945288301, 0, 0.961143732, -0.276048601, -0.98350364, -0.049934011, -0.173859805 | -502.944611, 115, 110.777809, -0.335102707, 0, -0.942181647, 0, 1, 0, 0.942181647, 0, -0.335102707 |
| C_plate | C1, character hidden | as C1 | |

Variants (var_*) all used the A1 camera.

# 這個 fork 改了什麼

在 Nanako0129/shanjie 的基礎上，給 macOS 15 個人使用的修改：

- **macOS 15 可用**：候選窗不用 macOS 26 的 NSGlassEffectView，改用 `GlassView`（NSVisualEffectView）；最低系統版本 15。
- **蘋果風格直式候選窗**（`ApplePanel.swift`）：28 pt 列、選中列整列強調色、核心預設直排。
- **半透明預測**：最佳預測以淡色文字浮在組字區後面，Tab 接受；設定→選字可開關。位置由「組字區起點＋量出來的文字寬度」算出（Electron 只回報起點）。
- **打錯注音修正**（`core/src/fuzzy.rs`）：新增 `FUZZY_WIDE`（送氣／翹舌／ㄣㄥ／ㄢㄤ／聲調類別）與 `FUZZY_KEYS`（鍵盤上下左右鄰鍵，含聲調鍵，對合法音節也生效）；預設旗標 112，`DELTA_SOUND` 2.5。
- **中英混打預設關**。
- **修正**：輸入來源圖示標籤至少兩個字（一個字會讓系統的切換提示崩潰，備忘錄閃退）。

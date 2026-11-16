# Handwriting Notebook App (កម្មវិធីកត់ត្រាមេរៀនដោយសរសេរដៃ)

កម្មវិធីទូរស័ព្ទ និង Tablet សម្រាប់កត់ត្រាមេរៀនដោយការសរសេរដៃ (Handwriting Note-taking App) បង្កើតឡើងដោយប្រើ **Flutter**, **Riverpod**, **Hive (Auto-Save)** និង **Perfect Freehand**។

## មុខងារសំខាន់ៗ (Key Features)
1. **Home / Dashboard Screen**:
   - បង្កើត និងគ្រប់គ្រង **Folders** តាមមុខវិជ្ជា និងពណ៌សម្គាល់។
   - បង្ហាញបញ្ជី **Notebooks** ជា GridView រួមជាមួយ **Live Vector Thumbnail** ដែលបង្ហាញទឹកប៊ិច និងប្រភេទក្រដាសផ្ទាល់។
2. **Canvas / Workspace Screen**:
   - **Toolbar**: Undo/Redo, ផ្លាស់ប្តូរប្រភេទក្រដាស (ក្រដាសបន្ទាត់ Ruled, ក្រដាសក្រឡា Grid, ក្រដាសទទេ Blank), ប៊ិច (Pen ជ្រើសរើសពណ៌ និងទំហំ), ហាយឡាយ (Highlighter), ជ័រលុប (Eraser)។
   - **Add-ons**: បញ្ចូលរូបភាពពីទូរស័ព្ទចូលក្នុងសន្លឹកកិច្ចការ (អាចអូសប្តូរទីតាំង ឬលុបបាន)។
   - **Export**: រក្សាទុកសន្លឹកកិច្ចការជាឯកសារ **PDF** ឬ **រូបភាព PNG**។
3. **Split-Screen / Zoom Window Mode (មុខងារសរសេរដៃពិសេស)**:
   - **ផ្នែកខាងលើ (Preview Area)**: បង្ហាញសន្លឹកកិច្ចការពេញ និងមានប្រអប់ **Zoom Target Box** ដែលអាចចុច ឬអូសផ្លាស់ប្តូរទីតាំងបាន។
   - **ផ្នែកខាងក្រោម (Zoom Writing Pad)**: ពង្រីកតំបន់នៅក្នុងប្រអប់ Zoom ឲ្យធំងាយស្រួលសរសេរអក្សរខ្មែរ/រូបមន្ត ដោយភ្ជាប់ **Real-time Sync** ទៅកាន់សន្លឹកខាងលើភ្លាមៗ។
   - **Auto-Advance**: នៅពេលសរសេរចូលដល់តំបន់ `Auto-Advance »` ផ្នែកខាងស្តាំ រួចដកប៊ិចឡើង ប្រអប់ Zoom នឹងរំកិលទៅមុខដោយស្វ័យប្រវត្តិ និងចុះបន្ទាត់ថ្មីពេលដល់គែមក្រដាស។
   - **Palm Rejection**: គាំទ្រទាំង **Palm Guard** (បដិសេធការប៉ះដែលមានផ្ទៃធំដូចជាប្រអប់ដៃ) និងមុខងារ **Stylus Only Mode**។

## របៀបដំណើរការ Project (How to Run)
បើក Terminal នៅក្នុង Folder `d:\Project\Notebook` រួចដំណើរការ៖

```bash
# ១. បង្កើត Platform folders (android, ios, windows) ប្រសិនបើមិនទាន់មាន
flutter create .

# ២. ទាញយក Packages ទាំងអស់
flutter pub get

# ៣. ដំណើរការកម្មវិធី
flutter run
```

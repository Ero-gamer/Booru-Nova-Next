# 发布流程（Android）

本文件是发布链的**唯一操作说明**。手工发布容易漏步骤，漏掉的每一样都曾经出过事：
漏 `--target-platform` 会让通用包从 38MB 涨到 56MB；漏签名校验会让 debug 签名的包发出去。

## 0. 不可违反的两条红线

1. **密钥不可更换。** `android/release.jks` 一旦更换，所有已安装用户必须卸载重装才能升级
   （签名不一致 → `INSTALL_FAILED_UPDATE_INCOMPATIBLE`）。
2. **口令可以更换，且不影响升级。** 换口令只改容器密码，密钥对与证书不变：

   ```bash
   keytool -storepasswd -keystore android/release.jks -storepass <旧口令> -new <新口令>
   # PKCS12 的 key password 跟 store password 一致，改完同步更新 android/key.properties
   ```

## 1. 密钥台账

| 项 | 值 |
|---|---|
| 签名证书 SHA-256 | `5687a29420f6e278faae3ff97e420ce1adc5517d8b5a6cf759995f38c681f3cd` |
| DN | `CN=Dev` |
| 签名方案 | APK Signature Scheme v2（minSdk 26，v1 不需要） |
| 密钥文件 | `android/release.jks`（**不入库**，`android/.gitignore` 已忽略） |
| 口令文件 | `android/key.properties`（**不入库**） |

**备份要求**：`release.jks` + `key.properties` 至少两份离线副本（例如密码管理器附件 + 加密U盘）。
当前这份密钥只存在于开发机，磁盘损坏 = 永久失去所有用户的升级能力。

> ⚠️ 口令 `123456` 属可离线爆破的强度，务必按第 0 节换成随机串。
> 换口令后**必须**同步更新 `key.properties` 与 CI Secrets，否则下一次发布直接失败（这是有意的硬失败）。

## 2. 版本号

唯一来源是 `pubspec.yaml` 的 `version: <name>+<code>`：

* `versionName` = `1.8.2`，`versionCode` = `24`（**只增不减**，Android 硬约束）。
* `android/app/build.gradle` 不再回落到 `1.0`：缺 `flutter.versionCode` / `flutter.versionName`
  会直接构建失败，提示你去用 `flutter build`（由 flutter 工具把版本写进 `local.properties`）。
* 发版前先提交 `chore(release): bump version to x.y.z+N`，Tag 打在**同一个提交**上。

## 3. 构建与上传

```bash
# 一次性：确保签名就位
ls android/key.properties android/release.jks

# 构建（两个包一起出：arm64 专用 + 双 ABI 通用）
flutter build apk --release --target-platform android-arm64,android-x64

# 产物
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk   # ~19MB，绝大多数手机
build/app/outputs/flutter-apk/app-release.apk             # ~38MB，arm64 + x86_64
```

`--target-platform` 不能省：不加会把 armeabi-v7a 一起打进通用包（38MB → 56MB），
且与 README 里声明的体积不符。

也可直接运行脚本（含体积/签名/哈希自检）：

```bash
tool/release_android.sh            # 只构建并自检
tool/release_android.sh --publish  # 构建自检后创建 GitHub Release 并上传
```

## 4. 发布前自检清单

- [ ] `flutter analyze --fatal-infos` 无问题
- [ ] `flutter test` 全绿
- [ ] `apksigner verify --print-certs` 的证书 SHA-256 == 台账里的 `5687a294…`
- [ ] 装机清单无 `REQUEST_INSTALL_PACKAGES` / `POST_NOTIFICATIONS`，且 `allowBackup="false"`
      （CI 里有断言，本地可 `aapt2 dump xmltree <apk> --file AndroidManifest.xml`）
- [ ] 通用包 ≈38MB（不是 56MB）
- [ ] README 的「最新版本」与下载表体积已同步

## 5. CI

| 工作流 | 触发 | 作用 |
|---|---|---|
| `.github/workflows/ci.yml` | push main / PR | analyze + test + 合并清单断言 |
| `.github/workflows/release.yml` | push tag `v*` | 构建 + 断言签名证书 + 上传 Release 资产 |

Release 工作流需要四个仓库 Secret（Settings → Secrets → Actions）：

| Secret | 内容 |
|---|---|
| `KEYSTORE_BASE64` | `base64 -w0 android/release.jks` 的输出 |
| `KEYSTORE_PASSWORD` | keystore 口令 |
| `KEY_PASSWORD` | key 口令（PKCS12 下同 `KEYSTORE_PASSWORD`） |
| `KEY_ALIAS` | `key` |

CI 中写死了证书指纹断言：用错密钥会当场失败，不会发出装不上的包。

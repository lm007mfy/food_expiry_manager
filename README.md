# food_expiry_manager
 一款基于 Flutter + SQLite 的本地食品保质期管理 Android 应用，支持多记录追踪、商家管理、临期/过期提醒、数据导出备份，帮助用户全面管理食品保质期。

---

## 一、项目简介

食品保质期助手 v2.6 是在 v1.0 基础上经过多次迭代升级的成熟版本。核心改进包括：按记录维度的临期提醒系统、商家关联查询、三级颜色分级提醒、彻底删除功能等。所有数据存储在手机本地 SQLite 数据库中，无需联网。

---

## 二、技术栈

| 技术                 | 版本     | 说明                      |
| ------------------ | ------ | ----------------------- |
| Flutter            | 3.29.3 | 跨平台 UI 框架               |
| Dart               | 3.7.2  | 编程语言                    |
| sqflite            | 2.3.0+ | SQLite 本地数据库（version 6） |
| provider           | 6.1.1  | 状态管理                    |
| excel              | 4.0.6  | Excel 导出                |
| image_picker       | 1.0.7  | 拍照/相册选图                 |
| shared_preferences | 2.2.2  | 本地偏好存储                  |
| path_provider      | 2.1.1  | 文件路径管理                  |
| intl               | 0.19.0 | 国际化/日期格式化               |
| permission_handler | 11.3.0 | 权限管理                    |

---

## 三、功能说明

### 3.1 主页 — 实时时钟 + 临期/过期提醒

- **实时时钟**：顶部绿色渐变区域显示当前年月日、星期、时分秒
  - 使用 `ValueListenableBuilder` 优化，每秒仅重建时钟部分，不影响列表性能
- **临期提醒公告栏**：按**每条历史记录**独立显示（非按食品聚合）
  - 同一食品的多条记录均会分别出现在提醒列表中
  - 每条显示：食品名称、剩余时间、数量、商家、录入时间
  - **三级颜色分级**：
    - 🔴 红色（≤7 天）：紧急，需尽快处理
    - 🟠 橙色（8-30 天）：临期，注意关注
    - 🟢 绿色（>30 天）：安全，暂无风险
    - ⚫ 灰色（已过期）：已过期 X 天
  - 点击右上角 `×` 可关闭**单条记录**的提醒
  - **过期食品也会显示**，不再遗漏
- **提醒阈值设置**：点击右上角齿轮图标，可选择 1/2/3 个月作为提醒范围
- **自动刷新**：每小时自动刷新临期数据，跨天/跨午夜数据保持准确

### 3.2 食品管理 — 增删改查

- **食品列表**：展示所有在售食品
  - 每行显示：食品名称首字图标（或照片）、食品名称、**最临近到期的记录**的商家名称和剩余天数
  - **左滑删除**（软删除）：标记为"已售罄"，历史记录保留，可通过导出找回
  - **长按彻底删除**（v2.6 新增）：弹出红色警告确认框，确认后永久删除该食品及其所有历史记录、关闭记录，无法恢复
- **搜索**：顶部搜索框支持按食品名称或商家名称模糊搜索
- **筛选抽屉**（左侧滑出）：
  - **食品分类**：按分类折叠展示，点击食品跳转详情
    - 默认分类：未分类、饮料、零食、调味品、乳制品、冷冻食品、主食、水果
  - **商家分类**：列出所有商家及关联食品数量（基于历史记录统计）
    - 点击商家 → 进入商家食品列表（显示该商家关联的所有食品）
    - 无关联食品的商家可长按删除
- **新增食品**：点击右下角 `+`，选择"增加食品"或"增加商家"
- **食品详情**：点击食品进入详情页
  - 显示该食品的所有历史记录
  - 每条记录：录入时间、生产日期、保质期、商家、数量、距到期天数
  - 可新增记录、编辑记录（直接更新原记录）、删除记录
  - 若从商家筛选进入，标题栏显示"食品名 - 商家名"，仅显示该商家的记录
- **新增/编辑记录**：
  - 选择生产日期（日期选择器）
  - 输入保质期天数
  - 选择商家（下拉列表，可选）
  - 输入数量
  - 自动计算到期日并实时预览距到期天数
  - 编辑模式直接更新原记录，不产生新记录

### 3.3 历史记录 — 恢复、导出与备份

- **已关闭提醒恢复区**（始终显示在顶部）：
  - 显示所有已关闭的临期提醒记录（按记录维度）
  - 每条显示：食品名称 + 距到期天数 + [恢复] 按钮
  - **[全部恢复]** 按钮：一键恢复所有已关闭提醒
  - 过期记录显示灰色标识
- **历史记录列表**：展示所有食品的历史录入记录，按录入时间倒序
  - 每条显示：食品名称、录入时间、商家、数量、保质期、距到期天数（实时计算）
- **数据导出**（Excel .xlsx）：
  - 导出全部食品 / 仅在售 / 仅已售罄
  - 报表字段：食品名称、商家名称、生产日期、保质期、到期日、距到期天数、数量、状态
- **数据备份与恢复**：
  - 备份：导出全部数据（food、food_history、merchant、category、announcement_dismiss）为 JSON
  - 恢复：从最新 JSON 备份文件导入，覆盖当前数据

---

## 四、数据库设计（v2.6 — version 6）

### food 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PK | 自增主键 |
| name | TEXT | 食品名称 |
| image_path | TEXT | 图片路径 |
| production_date | TEXT | 生产日期 |
| quantity | INTEGER | 数量 |
| expiry_date | TEXT | 到期日（最近记录的计算值） |
| created_at | TEXT | 创建时间 |
| updated_at | TEXT | 更新时间 |
| notification_dismissed | INTEGER | 预留字段 |
| category_id | INTEGER FK | 关联分类 |
| shelf_life_days | INTEGER | 保质期天数 |
| merchant_id | INTEGER FK | 关联商家 |
| is_deleted | INTEGER | 软删除标记（0/1） |

### food_history 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PK | 自增主键 |
| food_id | INTEGER FK | 关联食品 ID（CASCADE） |
| food_name | TEXT | 食品名称快照 |
| production_date | TEXT | 生产日期 |
| quantity | INTEGER | 数量 |
| expiry_date | TEXT | 到期日 |
| days_remaining | INTEGER | 距到期天数（入库快照，显示时实时计算） |
| recorded_at | TEXT | 录入时间 |
| merchant_name | TEXT | 商家名称 |
| shelf_life_days | INTEGER | 保质期天数 |

### merchant 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PK | 自增主键 |
| name | TEXT UNIQUE | 商家名称 |
| created_at | TEXT | 创建时间 |

### category 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PK | 自增主键 |
| name | TEXT | 分类名称 |
| icon | TEXT | 分类图标（emoji） |

### announcement_dismiss 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PK | 自增主键 |
| food_id | INTEGER FK | 关联食品 ID |
| history_id | INTEGER | 关联历史记录 ID（v2.4 新增） |
| dismissed_at | TEXT | 关闭时间 |

---

## 五、项目结构

```
lib/
├── main.dart                              # 应用入口 + 主题 + 三 Tab 导航
├── db/
│   └── database_helper.dart               # SQLite 数据库（version 6）
├── models/
│   ├── food.dart                          # 食品模型
│   ├── food_history.dart                  # 历史记录模型（含 realDaysRemaining）
│   ├── merchant.dart                      # 商家模型
│   └── category.dart                      # 分类模型
├── providers/
│   └── app_state.dart                     # 全局状态（Provider）
├── screens/
│   ├── home/
│   │   └── home_screen.dart               # 主页（时钟 + 三级颜色提醒）
│   ├── manage/
│   │   └── manage_screen.dart             # 食品管理（搜索 + 筛选 + 软/硬删除）
│   ├── history/
│   │   └── history_screen.dart            # 历史记录（恢复 + 导出 + 备份）
│   └── detail/
│       ├── food_detail_screen.dart        # 食品详情（记录列表 + 商家筛选）
│       ├── record_edit_screen.dart        # 记录编辑/新增
│       └── merchant_foods_screen.dart     # 商家关联食品列表
├── widgets/
│   └── filter_drawer.dart                 # 筛选抽屉（分类 + 商家）
└── utils/
    └── date_utils.dart                    # 日期格式化工具
```

---

## 六、页面导航

底部导航栏三个 Tab：

| Tab | 图标 | 页面 | 功能 |
|-----|------|------|------|
| 主页 | 🏠 | HomeScreen | 实时时钟 + 三级颜色临期/过期提醒 |
| 处理 | 📦 | ManageScreen | 食品管理 + 搜索 + 筛选 + 软/硬删除 |
| 历史 | 📜 | HistoryScreen | 历史记录 + 恢复 + 导出 + 备份恢复 |

---

## 七、界面主题

- 主色调：绿色（#4CAF50）
- 顶部导航栏：绿色背景 + 白色文字 + 阴影
- 卡片圆角：12px，白色背景
- 背景色：浅灰（#F5F5F5）
- Material Design 3

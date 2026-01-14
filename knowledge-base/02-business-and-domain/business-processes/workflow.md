# Smart Screen - 核心业务流程

> **层级**: L2 - 业务与领域（What）  
> **角色**: 业务专家 / 架构师  
> **本质**: 问题空间建模

## 核心流程概览

```mermaid
graph LR
    A[配置] --> B[录制]
    B --> C[增强]
    C --> D[编辑]
    D --> E[导出]
```

---

## 流程 1：录制配置流程

### 流程图

```mermaid
graph TB
    Start([开始]) --> SelectSource[选择捕获源]
    SelectSource --> SourceType{捕获类型}
    
    SourceType -->|全屏| FullScreen[选择显示器]
    SourceType -->|窗口| Window[选择窗口]
    SourceType -->|区域| Region[框选区域]
    
    FullScreen --> ConfigAudio[配置音频]
    Window --> ConfigAudio
    Region --> ConfigAudio
    
    ConfigAudio --> AudioType{音频类型}
    AudioType -->|麦克风| Mic[选择麦克风设备]
    AudioType -->|系统音频| System[配置虚拟驱动]
    AudioType -->|无| NoAudio[跳过]
    
    Mic --> ConfigOverlay[配置叠加层]
    System --> ConfigOverlay
    NoAudio --> ConfigOverlay
    
    ConfigOverlay --> OverlayType{叠加类型}
    OverlayType -->|摄像头| Webcam[配置 PiP]
    OverlayType -->|无| NoOverlay[跳过]
    
    Webcam --> Ready[准备就绪]
    NoOverlay --> Ready
    Ready --> End([完成配置])
```

### 流程说明

| 阶段 | 活动 | 系统支持 |
|------|------|----------|
| **选择捕获源** | 用户选择录制范围 | 提供全屏/窗口/区域三种模式 |
| **配置音频** | 用户选择音频输入 | 自动检测可用设备，提示系统音频配置 |
| **配置叠加层** | 用户选择是否添加摄像头 | 提供位置、大小、样式配置 |

---

## 流程 2：录制执行流程

### 流程图

```mermaid
graph TB
    Start([开始录制]) --> Init[初始化捕获引擎]
    Init --> StartCapture[启动视频捕获]
    StartCapture --> StartAudio[启动音频捕获]
    StartAudio --> StartEvent[启动事件记录]
    
    StartEvent --> Recording{录制中}
    
    Recording -->|用户暂停| Pause[暂停捕获]
    Pause --> Recording
    
    Recording -->|用户停止| Stop[停止捕获]
    
    Stop --> Finalize[完成文件写入]
    Finalize --> SaveMeta[保存元数据]
    SaveMeta --> End([录制完成])
```

### 数据流

```mermaid
flowchart LR
    subgraph 采集层
        Screen[屏幕帧] --> VideoBuffer[视频缓冲]
        Mic[麦克风] --> AudioBuffer[音频缓冲]
        Events[鼠标/键盘] --> EventLog[事件日志]
    end
    
    subgraph 处理层
        VideoBuffer --> Encoder[H.264 编码器]
        AudioBuffer --> AudioEncoder[AAC 编码器]
    end
    
    subgraph 存储层
        Encoder --> Muxer[封装器]
        AudioEncoder --> Muxer
        Muxer --> File[MP4/MOV 文件]
        EventLog --> MetaFile[元数据文件]
    end
```

### 关键技术点

| 环节 | 技术方案 | 注意事项 |
|------|----------|----------|
| **视频采集** | ScreenCaptureKit / CGDisplayStream | 优先使用 ScreenCaptureKit（macOS 12.3+） |
| **音频采集** | AVCaptureDevice | 系统音频需要 BlackHole 驱动 |
| **编码** | VideoToolbox (H.264/HEVC) | 硬件加速，低 CPU 占用 |
| **封装** | AVAssetWriter | 支持 MP4/MOV |
| **同步** | CMSampleBuffer.presentationTimeStamp | 统一时间基准 |

---

## 流程 3：增强处理流程

### 流程图

```mermaid
graph TB
    Start([开始增强]) --> LoadMedia[加载原始素材]
    LoadMedia --> LoadEvents[加载事件日志]
    
    LoadEvents --> AutoZoom{Auto Zoom?}
    AutoZoom -->|是| DetectHotspot[检测热点区域]
    DetectHotspot --> GenZoomPlan[生成缩放计划]
    GenZoomPlan --> CursorSmooth
    AutoZoom -->|否| CursorSmooth{Cursor Smoothing?}
    
    CursorSmooth -->|是| FilterCursor[滤波光标轨迹]
    FilterCursor --> Interpolate[插值生成平滑路径]
    Interpolate --> ClickHL
    CursorSmooth -->|否| ClickHL{Click Highlight?}
    
    ClickHL -->|是| GenHighlight[生成点击动画]
    GenHighlight --> Render
    ClickHL -->|否| Render[渲染合成]
    
    Render --> Output[输出增强后素材]
    Output --> End([增强完成])
```

### Auto Zoom 算法流程

```mermaid
flowchart TB
    subgraph 事件分析
        Events[事件日志] --> Window[滑动窗口]
        Window --> Density[计算事件密度]
        Density --> Hotspots[识别热点]
    end
    
    subgraph 缩放规划
        Hotspots --> Segments[生成 ZoomSegment]
        Segments --> Easing[应用缓动曲线]
        Easing --> Plan[缩放计划]
    end
    
    subgraph 渲染
        Plan --> Transform[仿射变换]
        Transform --> Crop[裁剪]
        Crop --> Scale[缩放]
        Scale --> Output[输出帧]
    end
```

### Cursor Smoothing 算法

| 算法 | 特点 | 适用场景 |
|------|------|----------|
| **EWMA** | 简单快速，实时性好 | 轻度平滑 |
| **Kalman Filter** | 预测性强，平滑效果好 | 中度平滑 |
| **Bezier 插值** | 曲线平滑，视觉效果佳 | 高度平滑 |

---

## 流程 4：编辑流程

### 流程图

```mermaid
graph TB
    Start([开始编辑]) --> LoadTimeline[加载时间线]
    LoadTimeline --> Preview[预览播放]
    
    Preview --> EditAction{编辑操作}
    
    EditAction -->|裁剪| Trim[设置入点/出点]
    EditAction -->|删除| Cut[标记删除片段]
    EditAction -->|变速| Speed[设置速度倍率]
    EditAction -->|分割| Split[分割片段]
    
    Trim --> UpdateTimeline[更新时间线]
    Cut --> UpdateTimeline
    Speed --> UpdateTimeline
    Split --> UpdateTimeline
    
    UpdateTimeline --> Preview
    
    Preview -->|确认| Save[保存编辑]
    Save --> End([编辑完成])
```

### 非破坏性编辑原理

```
原始素材: [===========================================]
                    ↓ 编辑操作
时间线:   [====] [=======] [====]
          seg1    seg2     seg3
          
seg1: sourceRange(0-5s), speed(1.0x)
seg2: sourceRange(10-20s), speed(1.5x)
seg3: sourceRange(25-30s), speed(1.0x)

导出时按时间线重新组合，原始素材不变
```

---

## 流程 5：导出流程

### 流程图

```mermaid
graph TB
    Start([开始导出]) --> SelectPreset[选择预设]
    SelectPreset --> CustomConfig{自定义配置?}
    
    CustomConfig -->|是| Config[配置参数]
    CustomConfig -->|否| Validate[验证配置]
    Config --> Validate
    
    Validate --> PrepareAsset[准备资源]
    PrepareAsset --> StartExport[开始导出]
    
    StartExport --> Processing{处理中}
    Processing -->|进度更新| UpdateProgress[更新进度条]
    UpdateProgress --> Processing
    
    Processing -->|完成| Finalize[完成写入]
    Processing -->|取消| Cleanup[清理临时文件]
    Processing -->|错误| HandleError[错误处理]
    
    Finalize --> Notify[通知用户]
    Cleanup --> End([导出结束])
    HandleError --> End
    Notify --> End
```

### 导出管线

```mermaid
flowchart LR
    subgraph 输入
        Video[视频轨道]
        Audio[音频轨道]
        Timeline[时间线]
    end
    
    subgraph 处理
        Video --> Decode[解码]
        Decode --> Transform[变换/增强]
        Transform --> Encode[重新编码]
        
        Audio --> AudioDecode[解码]
        AudioDecode --> AudioProcess[处理/混音]
        AudioProcess --> AudioEncode[重新编码]
    end
    
    subgraph 输出
        Encode --> Mux[封装]
        AudioEncode --> Mux
        Mux --> File[输出文件]
    end
```

---

## 异常处理流程

### 录制异常

```mermaid
graph TB
    Recording[录制中] --> Exception{异常类型}
    
    Exception -->|权限撤销| PermError[权限错误]
    Exception -->|设备断开| DeviceError[设备错误]
    Exception -->|磁盘满| DiskError[磁盘错误]
    Exception -->|内存不足| MemError[内存错误]
    
    PermError --> SavePartial[保存已录制内容]
    DeviceError --> SavePartial
    DiskError --> SavePartial
    MemError --> SavePartial
    
    SavePartial --> Notify[通知用户]
    Notify --> Recovery[提供恢复选项]
```

### 恢复策略

| 异常类型 | 恢复策略 |
|----------|----------|
| 权限撤销 | 保存已录制内容，提示重新授权 |
| 设备断开 | 保存已录制内容，提示重新连接 |
| 磁盘满 | 保存到临时位置，提示清理空间 |
| 内存不足 | 强制写入磁盘，降低缓冲区大小 |
| 应用崩溃 | 下次启动时检测并恢复临时文件 |

## 相关文档

- [领域模型](../domain-models/domain-model.md)
- [业务规则](../business-rules/rules.md)

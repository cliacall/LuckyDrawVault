# LuckyDrawVault

质押抽奖金库 — 质押越多中奖概率越高，中奖者平分80%奖池

## OpenFour 模块

直接集成到 four.meme OpenFour 发射引擎中。

## 合约架构

```
contracts/
├── LuckyDrawVault.sol              # 主合约
├── interfaces/
│   ├── IOpenFourVault.sol   # OpenFour Vault 接口
│   ├── ITagDescriptor.sol   # 模块标签接口
│   └── IOpenFourModuleSchema.sol  # 前端表单Schema接口
```

## 部署

1. 访问 https://four.meme/zh-TW/contract/create
2. 上传合约文件
3. 填写信息并提交审核

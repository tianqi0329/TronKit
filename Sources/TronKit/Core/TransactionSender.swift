import Foundation

class TransactionSender {
    private let tronGridProvider: TronGridProvider

    init(tronGridProvider: TronGridProvider) {
        self.tronGridProvider = tronGridProvider
    }
}

extension TransactionSender {
    func sendTransaction(contract: Contract, signer: Signer, feeLimit: Int?) async throws -> CreatedTransactionResponse {
        var createdTransaction: CreatedTransactionResponse

        guard let contract = contract as? SupportedContract else {
            throw Kit.SendError.notSupportedContract
        }

        switch contract {
        case let transfer as TransferContract:
            createdTransaction = try await tronGridProvider.createTransaction(ownerAddress: transfer.ownerAddress.hex, toAddress: transfer.toAddress.hex, amount: transfer.amount)

        case let smartContract as TriggerSmartContract:
            guard let functionSelector = smartContract.functionSelector,
                  let parameter = smartContract.parameter,
                  let feeLimit
            else {
                throw Kit.SendError.invalidParameter
            }

            createdTransaction = try await tronGridProvider.triggerSmartContract(
                ownerAddress: smartContract.ownerAddress.hex,
                contractAddress: smartContract.contractAddress.hex,
                functionSelector: functionSelector,
                parameter: parameter,
	       callValue: smartContract.callValue,
                feeLimit: feeLimit,
		
            )

        default: throw Kit.SendError.notSupportedContract
        }

        let rawData = try Protocol_Transaction.raw(serializedData: createdTransaction.rawDataHex)

guard rawData.contract.count == 1,
      let contractMessage = rawData.contract.first else {
    print("❌ Contract count 异常: \(rawData.contract.count)")
    throw Kit.SendError.abnormalSend
}

 print("=== 开始数据比较调试 ===")

do {
    let contractSerializedData = try contract.protoMessage.serializedData()
    let parameterValueData = try contractMessage.parameter.value

    print("📊 数据大小: \(contractSerializedData.count) vs \(parameterValueData.count)")
    
    // 尝试解析为具体的 TriggerSmartContract 对象进行比较
    let contractTrigger = try Protocol_TriggerSmartContract(serializedData: contractSerializedData)
    let parameterTrigger = try Protocol_TriggerSmartContract(serializedData: parameterValueData)
    
    print("🔬 对象字段比较:")
    print("合约地址: \(contractTrigger.contractAddress) vs \(parameterTrigger.contractAddress)")
    print("所有者地址: \(contractTrigger.ownerAddress) vs \(parameterTrigger.ownerAddress)")
    print("CallValue: \(contractTrigger.callValue) vs \(parameterTrigger.callValue)")
    print("Data 大小: \(contractTrigger.data.count) vs \(parameterTrigger.data.count)")
    
    // 比较 data 字段的内容
    if contractTrigger.data != parameterTrigger.data {
        print("❌ Data 字段内容不同")
        let contractDataHex = contractTrigger.data.toHexString()
        let parameterDataHex = parameterTrigger.data.toHexString()
        
        print("合约Data hex 前100字符: \(String(contractDataHex.prefix(100)))")
        print("参数Data hex 前100字符: \(String(parameterDataHex.prefix(100)))")
        
        // 找出第一个差异
        let minLength = min(contractTrigger.data.count, parameterTrigger.data.count)
        for i in 0..<min(10, minLength) {
            if contractTrigger.data[i] != parameterTrigger.data[i] {
                print("Data 差异位置 \(i): 合约=0x\(String(format: "%02x", contractTrigger.data[i])), 参数=0x\(String(format: "%02x", parameterTrigger.data[i]))")
                break
            }
        }
    } else {
        print("✅ Data 字段相同")
    }
    
    // 检查其他字段
    print("CallTokenValue: \(contractTrigger.callTokenValue) vs \(parameterTrigger.callTokenValue)")
    
    // 如果有 tokenId 字段（根据实际 Protocol_TriggerSmartContract 定义）
    // print("TokenId: \(contractTrigger.tokenId) vs \(parameterTrigger.tokenId)")
    
} catch {
    print("❌ 解析错误: \(error)")
    throw error
}

print("=== 数据比较结束 ===")

       guard rawData.contract.count == 1,
              let contractMessage = rawData.contract.first,
              try contractMessage.parameter.value == (contract.protoMessage.serializedData())
        else {
            throw Kit.SendError.abnormalSend
       }


        let signature = try signer.signature(hash: createdTransaction.txID)

        var transaction = Protocol_Transaction()
        transaction.rawData = rawData
        transaction.signature = [signature]

        try await tronGridProvider.broadcastTransaction(hexData: transaction.serializedData())

        return createdTransaction
    }
}
extension Data {
    func toHexString() -> String {
        return map { String(format: "%02x", $0) }.joined()
    }
}
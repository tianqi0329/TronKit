import BigInt
import Foundation

/*class ApproveMethodFactory: IContractMethodFactory {
    let methodId: Data = ContractMethodHelper.methodId(signature: ApproveMethod.methodSignature)

    func createMethod(inputArguments: Data) throws -> ContractMethod {
        let spender = try Address(raw: inputArguments[12 ..< 32])
        let value = BigUInt(inputArguments[32 ..< 64])

        return ApproveMethod(spender: spender, value: value)
    }
}*/

class ApproveMethodFactory: IContractMethodFactory {
    let methodId: Data = ContractMethodHelper.methodId(signature: ApproveMethod.methodSignature)

    func createMethod(inputArguments: Data) throws -> ContractMethod {
        // ✅ 添加边界检查
        guard inputArguments.count >= 64 else {
            throw ContractMethodFactories.DecodeError.invalidABI
        }
        
        let spender = try Address(raw: inputArguments[12 ..< 32])
        
        // ✅ BigUInt 初始化不会返回 nil，直接使用
        let valueData = inputArguments[32 ..< 64]
        let value = BigUInt(valueData)

        return ApproveMethod(spender: spender, value: value)
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "./interfaces/IDataValidator.sol";

import "./libraries/Types.sol";
import "./libraries/String.sol";
import "./libraries/MessageDecoder.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract DataValidator is IDataValidator, Initializable {
    using String for string;
    using MessageDecoder for bytes;
    using MessageDecoder for string;
    using MessageDecoder for Types.EventLog;
    using String for uint256;
    bytes[] internal msgs;

    function initialize() public initializer {}

    function validateReceipt(
        string memory _bmc,
        string memory _prev,
        uint256 _seq,
        bytes memory _serializedMsg,
        bytes32 _receiptHash
    ) external virtual override returns (bytes[] memory) {
        uint256 nextSeq = _seq + 1;
        Types.Receipt memory receipt;
        Types.MessageEvent memory messageEvent;
        Types.ReceiptProof[] memory receiptProofs = _serializedMsg
            .decodeReceiptProofs();
        (, string memory contractAddr) = _prev.splitBTPAddress();
        if (msgs.length > 0) delete msgs;
        for (uint256 i = 0; i < receiptProofs.length; i++) {
            //receipt = receiptProofs[i].verifyMPTProof(_receiptHash);
            /* for (uint256 j = 0; j < receipt.eventLogs.length; j++) {
                if (!receipt.eventLogs[j].addr.compareTo(contractAddr))
                    continue;
                messageEvent = receipt.eventLogs[j].toMessageEvent();
                if (bytes(messageEvent.nextBmc).length != 0) {
                    if (messageEvent.seq > nextSeq) {
                        //string memory concat1 = string("BMVRevertInvalidSequenceHigher, messageeventseq").concat(messageEvent.seq.toString()).concat(", nextseq").concat(nextSeq.toString());
                        revert("BMVRevertInvalidSequenceHigher");
                    } else if (messageEvent.seq < nextSeq) {
                        //string memory concat1 = string("BMVRevertInvalidSequence, messageeventseq").concat(messageEvent.seq.toString()).concat(", nextseq").concat(nextSeq.toString());
                        revert("BMVRevertInvalidSequence");
                    } else if (messageEvent.nextBmc.compareTo(_bmc)) {
                        msgs.push(messageEvent.message);
                        nextSeq += 1;
                    }
                }
            } */
            for (uint256 j = 0; j < receiptProofs[i].events.length; j++) {
                messageEvent = receiptProofs[i].events[j];
                if (bytes(messageEvent.nextBmc).length != 0) {
                    //console.log(string("BMVRevertInvalidSequenceHigher, messageeventseq").concat(messageEvent.seq.toString()).concat(", nextseq").concat(nextSeq.toString()));
                    if (messageEvent.seq > nextSeq) {
                        //string memory concat1 = string("BMVRevertInvalidSequenceHigher, messageeventseq").concat(messageEvent.seq.toString()).concat(", nextseq").concat(nextSeq.toString());
                        revert("BMVRevertInvalidSequenceHigher");
                    } else if (messageEvent.seq < nextSeq) {
                        //string memory concat1 = string("BMVRevertInvalidSequence, messageeventseq").concat(messageEvent.seq.toString()).concat(", nextseq").concat(nextSeq.toString());
                        revert("BMVRevertInvalidSequence");
                    } else if (messageEvent.nextBmc.compareTo(_bmc)) {
                        msgs.push(messageEvent.message);
                        nextSeq += 1;
                    }
                }
            }
        }
        return msgs;
    }
}

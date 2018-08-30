package main

import (
	"github.com/hyperledger/fabric/core/chaincode/shim"
	"fmt"
	pb "github.com/hyperledger/fabric/protos/peer"
	"time"
	"encoding/json"
)

type Message struct {
	Id string `json:"id"`
	Creator  string   `json:"creator"`
	Title  string `json:"title"`
	Content string `json:"content"`
	CreateDate time.Time `json:"createDate"`
}

const (
	creatorIndex = "creator~id"
	titleIndex = "title~id"
)

type ContentChaincode struct {
}

func main() {
	err := shim.Start(new(ContentChaincode))
	if err != nil {
		fmt.Printf("Error starting Simple chaincode: %s\n", err)
	}
}

func (t *ContentChaincode) Init(stub shim.ChaincodeStubInterface) pb.Response {
	return shim.Success(nil)
}

func (t *ContentChaincode) Invoke(stub shim.ChaincodeStubInterface) pb.Response {
	function, args := stub.GetFunctionAndParameters()
	fmt.Printf("Function: %s, args: %s\n", function, args)

	switch function {
	case "create":
		return createMessage(stub, args)
	case "queryById":
		return queryById(stub, args)
	case "queryByTitle":
		return queryByTitle(stub, args)
	default:
		return shim.Error("unknown function: " + function)
	}

	return shim.Success(nil)
}

func createMessage(stub shim.ChaincodeStubInterface, args []string) pb.Response {
	if len(args) != 1 {
		fmt.Println("No enough args")
		return shim.Error("No enough args, 1 require")
	}

	messageJson := args[0]
	message := Message{}
	bytes := []byte(messageJson)
	err := json.Unmarshal(bytes, &message)
	//message.Id   //todo id
	if err != nil {
		return shim.Error(fmt.Sprintf("args error, not message json, %v", err))
	}

	if message.Id == "" || message.Title == "" || message.Content == "" {
		return shim.Error("title and content can not be empty!")
	}

	err2 := stub.PutState(message.Id, bytes)
	if err2 != nil {
		return shim.Error(err.Error())
	}

	//creatorIndex
	creatorIdIndexKey, err := stub.CreateCompositeKey(creatorIndex, []string{message.Creator, message.Id})
	if err != nil {
		return shim.Error(err.Error())
	}
	value := []byte{0x00}
	stub.PutState(creatorIdIndexKey, value)

	//titleIndex
	titleIdIndexKey, err := stub.CreateCompositeKey(titleIndex, []string{message.Title, message.Id})
	if err != nil {
		return shim.Error(err.Error())
	}
	stub.PutState(titleIdIndexKey, value)

	return shim.Success(bytes)
}

func queryById(stub shim.ChaincodeStubInterface, args []string) pb.Response {
	if len(args) != 1 {
		return shim.Error("Need 1 args")
	}

	messageId := args[0]
	if messageId == "" {
		return shim.Error("arg id can not be empty")
	}

	jsonBytes, err := stub.GetState(messageId)
	if err != nil {
		return shim.Error("Task not found")
	}

	return shim.Success(jsonBytes)
}


func queryByTitle(stub shim.ChaincodeStubInterface, args []string) pb.Response {
	if len(args) != 1 {
		return shim.Error("Need 1 args")
	}

	title := args[0]
	if title == "" {
		return shim.Error("arg title can not be empty")
	}

	titleResultsIterator, err := stub.GetStateByPartialCompositeKey(titleIndex, []string{title})
	if err != nil {
		return shim.Error(err.Error())
	}
	defer titleResultsIterator.Close()

	var result []Message
	for titleResultsIterator.HasNext() {
		responseRange, err := titleResultsIterator.Next()
		if err != nil {
			return shim.Error(err.Error())
		}

		indexName, compositeKeyParts, err := stub.SplitCompositeKey(responseRange.Key)
		if err != nil {
			return shim.Error(err.Error())
		}
		title := compositeKeyParts[0]
		messageId := compositeKeyParts[1]
		fmt.Printf("- found a message from index:%s title:%s id:%s\n", indexName, title, messageId)

		//queryById
		response := queryById(stub, []string{messageId})
		if response.Status != shim.OK {
			return shim.Error("Transfer failed: " + response.Message)
		}

		message := Message{}
		json.Unmarshal(response.Payload, &message)
		result = append(result, message)
	}
	returnBytes, e := json.Marshal(result)
	if e != nil {
		shim.Error(e.Error())
	}

	return shim.Success(returnBytes)
}

package main

import (
	"testing"
	"github.com/hyperledger/fabric/core/chaincode/shim"
	"time"
	"encoding/json"
	"fmt"
)

func TestQueryByTitle(t *testing.T)  {
	scc := new(ContentChaincode)
	stub := shim.NewMockStub("ex04", scc)

	message := Message{}
	message.Title = "test"
	message.Creator = "hrx"
	message.Content = "test,test, TestQueryByTitle"
	message.CreateDate = time.Now()
	message.Id = "123456"
	bytes, _ := json.Marshal(message)
	response := stub.MockInvoke("invoke", [][]byte{[]byte("create"), bytes})
	fmt.Println("++++++++++++message create:", response.Status == shim.OK, ",  message:", response.Message)

	message.Content = "ok, ok, well done!"
	message.Id = "9685"
	bytes2, _ := json.Marshal(message)
	stub.MockInvoke("invoke", [][]byte{[]byte("create"), bytes2})

	messageReturn := Message{}
	json.Unmarshal(response.Payload, &messageReturn)
	fmt.Println("++++++++++++returned messageId:", messageReturn.Id)
	//fmt.Println("++++++++++++returned message:", string(response.Payload))

	////queryById
	//queryByIdResult := stub.MockInvoke("invoke", [][]byte{[]byte("queryById"), []byte(messageReturn.Id)})
	//fmt.Println("++++++++++++queryById:", string(queryByIdResult.Payload))

	//queryByTitle
	queryByTitleResult := stub.MockInvoke("invoke", [][]byte{[]byte("queryByTitle"), []byte(message.Title)})
	fmt.Println("++++++++++++queryByTitle:", string(queryByTitleResult.Payload))
}


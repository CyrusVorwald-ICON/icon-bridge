#!/bin/sh
######################################## javascore service methods - start ######################################
source utils.sh
source rpc.sh
# Parts of this code is adapted from https://github.com/icon-project/btp/blob/goloop2moonbeam/testnet/goloop2moonbeam/scripts
deploy_javascore_bmc() {
  echo "deploying javascore BMC"
  cd $CONFIG_DIR
  goloop rpc sendtx deploy $CONTRACTS_DIR/javascore/bmc-optimized.jar \
    --content_type application/java \
    --param _net=$(cat net.btp.icon) | jq -r . >tx.bmc.icon
  extract_scoreAddress tx.bmc.icon bmc.icon
  echo "btp://$(cat net.btp.icon)/$(cat bmc.icon)" >btp.icon
}

deploy_javascore_bsh() {
  echo "deploying javascore Token BSH"
  cd $CONFIG_DIR
  goloop rpc sendtx deploy $CONTRACTS_DIR/javascore/bsh-optimized.jar \
    --content_type application/java \
    --param _bmc=$(cat bmc.icon) | jq -r . >tx.token_bsh.icon
  extract_scoreAddress tx.token_bsh.icon token_bsh.icon
}

deploy_javascore_irc2() {
  echo "deploying javascore IRC2Token"
  cd $CONFIG_DIR
  goloop rpc sendtx deploy $CONTRACTS_DIR/javascore/irc2-token-optimized.jar \
    --content_type application/java \
    --param _name=${TOKEN_NAME} \
    --param _symbol=${TOKEN_SYM} \
    --param _initialSupply=${TOKEN_SUPPLY} \
    --param _decimals=${TOKEN_DECIMALS} | jq -r . >tx.irc2_token.icon
  extract_scoreAddress tx.irc2_token.icon irc2_token.icon
}

bmc_javascore_addLink() {
  echo "Adding bsc link"
  cd $CONFIG_DIR
  LAST_BOCK=$(goloop_lastblock)
  LAST_HEIGHT=$(echo $LAST_BOCK | jq -r .height)
  LAST_HASH=0x$(echo $LAST_BOCK | jq -r .block_hash)
  echo "goloop height:$LAST_HEIGHT hash:$LAST_HASH"
  echo $LAST_HEIGHT >$CONFIG_DIR/offset.icon
  echo $LAST_HASH >$CONFIG_DIR/last.hash.icon
  goloop rpc sendtx call --to $(cat bmc.icon) \
    --method addLink \
    --param _link=$(cat btp.bsc) | jq -r . >tx/addLink.icon
  ensure_txresult tx/addLink.icon
  echo "Added Link $(cat btp.bsc)"


  echo "goloop_bmc_setLinkDelayLimit"
  goloop rpc sendtx call --to $(cat bmc.icon) \
    --method setLinkDelayLimit \
    --param _link=$(cat btp.bsc) \
    --param _value=3 |
    jq -r . >tx/setLinkDelayLimit.icon
  ensure_txresult tx/setLinkDelayLimit.icon

  echo "finished goloop_bmc_addLink"
}

bmc_javascore_addRelay() {
  echo "Adding bsc Relay"
  ICON_RELAY_USER=$(cat $GOLOOP_RPC_KEY_STORE | jq -r .address)
  cd $CONFIG_DIR
  goloop rpc sendtx call --to $(cat bmc.icon) \
    --method addRelay \
    --param _link=$(cat btp.bsc) \
    --param _addr=${ICON_RELAY_USER} | jq -r . >tx/addRelay.icon
  ensure_txresult tx/addRelay.icon
  echo "Added Link $(cat btp.bsc)"
}

bsh_javascore_register() {
  echo "Register ERC20 Token with BSH"
  cd $CONFIG_DIR
  FEE_NUMERATOR=0x64
  goloop rpc sendtx call --to $(cat token_bsh.icon) \
    --method register \
    --param name=${TOKEN_NAME} \
    --param symbol=${TOKEN_SYM} \
    --param feeNumerator=${FEE_NUMERATOR} \
    --param decimals=${TOKEN_DECIMALS} \
    --param address=$(cat irc2_token.icon) | jq -r . >tx/register.token.icon
  ensure_txresult tx/register.token.icon
}

bmc_javascore_addService() {
  echo "Adding Service Token BSH"
  cd $CONFIG_DIR
  goloop rpc sendtx call --to $(cat bmc.icon) \
    --method addService \
    --param _svc=${SVC_NAME} \
    --param _addr=$(cat token_bsh.icon) | jq -r . >tx/addService.icon
  ensure_txresult tx/addService.icon
}

bmc_javascore_getServices() {
  cd $CONFIG_DIR
  goloop rpc call --to $(cat bmc.icon) \
    --method getServices
}

bsh_javascore_balance() {
  cd $CONFIG_DIR
  if [ $# -lt 1 ]; then
    echo "Usage: bsh_balance [EOA=$(rpceoa)]"
    return 1
  fi

  local EOA=$(rpceoa $1)
  echo "Balance of user $EOA"
  goloop rpc call --to "$(extractAddresses "javascore" "TokenBSH")" \
    --method getBalance \
    --param user=$EOA \
    --param tokenName=$TOKEN_NAME
}

bsh_javascore_transfer() {
  cd $CONFIG_DIR
  if [ $# -lt 2 ]; then
    echo "Usage: bsh_transfer [VAL=0x10] [EOA=$(rpceoa)]"
    return 1
  fi
  local VAL=${1:-0x10}
  local EOA=$2
  local FROM=$(rpceoa $GOLOOP_RPC_KEY_STORE)
  echo "Transfering $VAL wei to: $EOA from: $FROM "
  TX=$(
    goloop rpc sendtx call --to "$(extractAddresses "javascore" "TokenBSH")" \
      --method transfer \
      --param tokenName=${TOKEN_NAME} \
      --param value=$VAL \
      --param to=btp://$BSC_BMC_NET/$EOA | jq -r .
  )
  ensure_txresult $TX
}

irc2_javascore_balance() {
  cd $CONFIG_DIR
  if [ $# -lt 1 ]; then
    echo "Usage: irc2_balance [EOA=$(rpceoa)]"
    return 1
  fi
  local EOA=$(rpceoa $1)
  balance=$(goloop rpc call --to "$(extractAddresses "javascore" "IRC2")" \
    --method balanceOf \
    --param _owner=$EOA | jq -r .)
  balance=$(hex2int $balance)
  balance=$(wei2coin $balance)
  echo "Balance: $balance"
}

check_alice_token_balance_with_wait() {
  echo "Checking Alice's balance..."
  cd $CONFIG_DIR
  ALICE_INITIAL_BAL=$(irc2_javascore_balance alice.ks.json)
  COUNTER=60
  while true; do
    printf "."
    if [ $COUNTER -le 0 ]; then
      printf "\nError: timed out while getting Alice's Balance: Balance unchanged\n"
      echo $ALICE_CURR_BAL
      exit 1
    fi
    sleep 3
    COUNTER=$(expr $COUNTER - 3)
    ALICE_CURR_BAL=$(irc2_javascore_balance alice.ks.json)
    if [ "$ALICE_CURR_BAL" != "$ALICE_INITIAL_BAL" ]; then
      printf "\nBTP Transfer Successfull! \n"
      break
    fi
  done
  echo "Alice's Balance after BTP transfer: $ALICE_CURR_BAL ETH"
}

irc2_javascore_transfer() {
  cd $CONFIG_DIR
  if [ $# -lt 1 ]; then
    echo "Usage: irc2_transfer [VAL=0x10] [EOA=Address of Token-BSH]"
    return 1
  fi
  local VAL=${1:-0x10}
  local EOA=$(rpceoa ${2:-"$(extractAddresses "javascore" "TokenBSH")"})
  local FROM=$(rpceoa $GOLOOP_RPC_KEY_STORE)
  echo "Transfering $VAL wei to: $EOA from: $FROM "
  TX=$(
    goloop rpc sendtx call --to "$(extractAddresses "javascore" "IRC2")" \
      --method transfer \
      --param _to=$EOA \
      --param _value=$VAL | jq -r .
  )
  ensure_txresult $TX
}

token_icon_fundBSH() {
  echo "funding BSH with 1000ETH tokens"
  cd $CONFIG_DIR
  weiAmount=$(coin2wei 1000)
  echo "Wei Amount: $weiAmount"
  irc2_javascore_transfer "$weiAmount"
  #echo "$tx" >tx/fundBSH.icon
  #ensure_txresult tx/fundBSH.icon
}

rpceoa() {
  local EOA=${1:-${GOLOOP_RPC_KEY_STORE}}
  if [ "$EOA" != "" ] && [ -f "$EOA" ]; then
    echo $(cat $EOA | jq -r .address)
  else
    echo $EOA
  fi
}

########################################################### javascore service methods - END #####################################################################

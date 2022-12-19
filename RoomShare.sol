// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./IRoomShare.sol";

contract RoomShare is IRoomShare {

    uint public roomId;
    uint public rentId;
    Room[] internal rooms;
    Rent[] internal rents;
    mapping (uint => Room) internal roomId2room;
    mapping (address => Rent[]) internal renter2rent;
    mapping (uint => Rent[]) internal roomId2rent;

    constructor(){
        roomId = 0;
        rentId = 0;
    }

  function getMyRents() external override view returns(Rent[] memory) {
    return renter2rent[msg.sender];
  }

  function getRoomRentHistory(uint _roomId) external override view returns(Rent[] memory) {
    return roomId2rent[_roomId];
  }

  function getAllRooms() external view returns (Room[] memory){
      return rooms;
  }

  function shareRoom( string calldata name, 
                      string calldata location, 
                      uint price ) external override {
    bool[] memory isRented = new bool[](365);

    rooms.push(Room(roomId, name, location, true, price, msg.sender, isRented));
    roomId2room[roomId] = rooms[rooms.length-1];
    emit NewRoom(roomId++);
  }

  function _createRent(uint256 _roomId, uint256 checkInDate, uint256 checkoutDate) external override {
    /**
     * 1. 함수를 호출한 사용자 계정으로 대여 객체를 만들고, 변수 저장 공간에 유의하며 체크인날짜부터 체크아웃날짜에 해당하는 배열 인덱스를 체크한다(초기값은 false이다.).
     * 2. 계정과 대여 객체들을 매핑한다. (대여 목록)
     * 3. 방 id와 대여 객체들을 매핑한다. (대여 히스토리)
     */
    Room storage room = roomId2room[_roomId];
    for(uint i = checkInDate; i < checkoutDate; i++){
        room.isRented[i] = true;
    }

    emit NewRent(_roomId, rentId++);
  }

  function rentRoom(uint _roomId, uint checkInDate, uint checkOutDate) payable external override  {
      Room memory room = roomId2room[_roomId];
      require(room.isActive, "room is not active");
      bool availableOnRequestedDates = true;
      for(uint i = checkInDate; i < checkOutDate; i++){
          if(room.isRented[i]){
              availableOnRequestedDates = false;
          }
      }
      require(availableOnRequestedDates, "room is not available on these dates");
      require(msg.value == (room.price * 1e15) * (checkOutDate - checkInDate), "wrong amount of Finney sent");

      bool sent = payable(room.owner).send(msg.value);
      require(sent, "Failed to send Ether");

      Rent memory rent = Rent(rentId, _roomId, checkInDate, checkOutDate, msg.sender);
      roomId2rent[_roomId].push(rent);
      renter2rent[msg.sender].push(rent);
      rents.push(rent);
      this._createRent(_roomId, checkInDate, checkOutDate);
    /**
     * 1. roomId에 해당하는 방을 조회하여 아래와 같은 조건을 만족하는지 체크한다.
     *    a. 현재 활성화(isActive) 되어 있는지
     *    b. 체크인날짜와 체크아웃날짜 사이에 예약된 날이 있는지 
     *    c. 함수를 호출한 유저가 보낸 이더리움 값이 대여한 날에 맞게 지불되었는지(단위는 1 Finney, 10^15 Wei) 
     * 2. 방의 소유자에게 값을 지불하고 (msg.value 사용) createRent를 호출한다.
     * *** 체크아웃 날짜에는 퇴실하여야하며, 해당일까지 숙박을 이용하려면 체크아웃날짜는 그 다음날로 변경하여야한다. ***
     */
  }


  function _sendFunds (address owner, uint256 value) external override {
      payable(owner).transfer(value);
  }
  
  

  function recommendDate(uint _roomId, uint checkInDate, uint checkOutDate) external override view returns(uint[2] memory) {
    bool[] storage roomAvailability = roomId2room[_roomId].isRented;

    bool foundDates = false;
    uint PossibleStaycheckOutDate = 0;
    uint PossibleStaycheckInDate = 0;
    for(uint i = checkInDate; i < checkOutDate; i++){
        if(!roomAvailability[i]){
          if(!foundDates){
            PossibleStaycheckInDate = i;
          } else {
            PossibleStaycheckOutDate = i + 1;
          }
          foundDates = true;
        }
    }
    require(foundDates, "no possible dates given between checkin and checkout dates.");
    return [PossibleStaycheckInDate, PossibleStaycheckOutDate];
    /**
     * 대여가 이미 진행되어 해당 날짜에 대여가 불가능 할 경우, 
     * 기존에 예약된 날짜가 언제부터 언제까지인지 반환한다.
     * checkInDate(체크인하려는 날짜) <= 대여된 체크인 날짜 , 대여된 체크아웃 날짜 < checkOutDate(체크아웃하려는 날짜)
     */
  }

    // optional 1
    // caution: 방의 소유자를 먼저 체크해야한다.
    // isActive 필드만 변경한다.
    function markRoomAsInactive(uint256 _roomId) external override{
        Room storage room = roomId2room[_roomId];
        require(msg.sender == room.owner, "sender is not owner");
        for(uint i = 0; i < rooms.length; i++){
          if(rooms[i].id == _roomId){
            rooms[i].isActive = false;
          }
        }
        room.isActive = false;
    }

    // optional 2
    // caution: 변수의 저장공간에 유의한다.
    // 첫날부터 시작해 함수를 실행한 날짜까지 isRented 필드의 초기화를 진행한다.
    function initializeRoomShare(uint _roomId, uint day) external override {
      Room storage room = roomId2room[_roomId];
      for(uint i = 0; i < day; i++){
        room.isRented[i] = false;
      }
      for(uint i = 0; i < rooms.length; i++){
          if(rooms[i].id == _roomId){
                  for(uint j = 0; j < day; j++){
                    rooms[i].isRented[j] = false;
                  }
          }
        }
    }

  // ...

}
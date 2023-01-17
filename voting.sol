pragma solidity  >=0.7.0 <0.9.0;

contract voting{
    //投票人
    struct Votor{
        int weight;                 //计票权重
        int voteRounds;             //投票轮数
        uint carbonEmissionLevel;   //碳排放水平
        int carbonCoin;             //代币
        int governanceToken;        //代币
        Proposal travelData;        //出行数据
    }

    //投票类型
    struct Proposal{
        int PassengerCars;
        int Motocycle;
        int Bus;
        int HeavyRail;
        int Walking;
        int Cycling;
        int weight;
    }

    //成员变量
    mapping(address=>Votor) public votors;
    int[5] public suggestAllowance;
    int public roundNow;
    int[] public decreasedAllowancePercentage;

    //构造函数
    constructor() public{
        suggestAllowance[0]=15;
        suggestAllowance[1]=18;
        suggestAllowance[2]=21;
        suggestAllowance[3]=24;
        suggestAllowance[4]=27;
    }

    //输入本周的出行数据
    function inputTravelData(Proposal memory proposal_) public{
        votors[msg.sender].travelData.PassengerCars=proposal_.PassengerCars;
        votors[msg.sender].travelData.Motocycle=proposal_.Motocycle;
        votors[msg.sender].travelData.Bus=proposal_.Bus;
        votors[msg.sender].travelData.HeavyRail=proposal_.HeavyRail;
        votors[msg.sender].travelData.Walking=proposal_.Walking;
        votors[msg.sender].travelData.Cycling=proposal_.Cycling;
    }

    ///输入碳排放等级
    function inputLevel(uint carbonEmissionLevel_) public{
        votors[msg.sender].carbonEmissionLevel=carbonEmissionLevel_-1;
    }
    
    //投票
    function vote(Proposal memory proposal_) public{
        votors[msg.sender].weight=1;
        Votor storage sender=votors[msg.sender];
        require(votors[msg.sender].voteRounds==roundNow,"Already voted.");
        int votingCarbonAllowance=(
            proposal_.PassengerCars*192+
            proposal_.Motocycle*103+
            proposal_.Bus*105+
            proposal_.HeavyRail*41
        )/100;
        int decreasedAllowancePercentage_=(
            suggestAllowance[votors[msg.sender].carbonEmissionLevel]-
            votingCarbonAllowance
        )*100/int(suggestAllowance[votors[msg.sender].carbonEmissionLevel]);
        decreasedAllowancePercentage.push(decreasedAllowancePercentage_);
        votors[msg.sender].voteRounds+=1;
        if(votors[msg.sender].voteRounds==4)
            votors[msg.sender].voteRounds=0;
    }

    //每一轮次结算
    function settle() public{
        int carbonSum=(
            votors[msg.sender].travelData.PassengerCars+
            votors[msg.sender].travelData.Motocycle+
            votors[msg.sender].travelData.Bus+
            votors[msg.sender].travelData.HeavyRail+
            votors[msg.sender].travelData.Walking+
            votors[msg.sender].travelData.Cycling
        );
        int carbonQuota=suggestAllowance[votors[msg.sender].carbonEmissionLevel]*carbonSum;
        int carbonCost=(
            votors[msg.sender].travelData.PassengerCars*192+
            votors[msg.sender].travelData.Motocycle*103+
            votors[msg.sender].travelData.Bus*105+
            votors[msg.sender].travelData.HeavyRail*41
        );
        int carbonCostKM=(
            votors[msg.sender].travelData.PassengerCars*100/carbonSum*192+
            votors[msg.sender].travelData.Motocycle*100/carbonSum*103+
            votors[msg.sender].travelData.Bus*100/carbonSum*105+
            votors[msg.sender].travelData.HeavyRail*100/carbonSum*41
        )/100;
        votors[msg.sender].carbonCoin += (carbonQuota-carbonCost)/1000;
        int decreasedAllowancePercentage_=0;
        for(uint i=0;i<decreasedAllowancePercentage.length;i++){
            decreasedAllowancePercentage_+=decreasedAllowancePercentage[i];
        }
        decreasedAllowancePercentage_/=int(decreasedAllowancePercentage.length);
        int nextWeekCarbonAllowance=suggestAllowance[votors[msg.sender].carbonEmissionLevel]*(
            1-(decreasedAllowancePercentage_/100)
        );
        int decreasedAllowance=suggestAllowance[votors[msg.sender].carbonEmissionLevel]-
        nextWeekCarbonAllowance;
        int residualAllowance=suggestAllowance[votors[msg.sender].carbonEmissionLevel]-
        carbonCostKM;
        votors[msg.sender].governanceToken+=(decreasedAllowance+residualAllowance);
    }

    //进入下一次循环
    function gotoNext() public{
        roundNow+=1;
        if(roundNow==4)
            roundNow=0;
        delete decreasedAllowancePercentage;
    }
}

//user 1:2 [123,4,1,23,5,23,1] [65,5,5,10,3,12,1]
//user 2:3 [45,21,23,112,23,2,1] [23,12,12,50,2,1,1]
//user 3:2 [100,0,2,59,2,1,1] [51,0,2,25,12,10,1]
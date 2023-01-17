pragma solidity  >=0.7.0 <0.9.0;

contract voting{
    //投票人
    struct Votor{
        uint weight;             //计票权重
        uint voteRounds;         //投票轮数
        uint vote;               //投票提案的索引
        Proposal travelData;     //出行数据
    }

    //投票类型
    struct Proposal{
        uint PassengerCars;
        uint Motocycle;
        uint Bus;
        uint HeavyRail;
        uint Walking;
        uint Cycling;
        uint weight;
    }

    //成员变量
    Proposal[][4] public proposals;
    mapping(address=>Votor) public votors;
    uint roundMax;

    //构造函数
    constructor() public{

    }

    //投票
    function vote(Proposal memory proposal_) public{
        votors[msg.sender].weight=1;
        Votor storage sender=votors[msg.sender];
        require(sender.voteRounds!=4,"Already voted.");
        proposals[sender.voteRounds].push(Proposal({
            PassengerCars:proposal_.PassengerCars,
            Motocycle:proposal_.Motocycle,
            Bus:proposal_.Bus,
            HeavyRail:proposal_.HeavyRail,
            Walking:proposal_.Walking,
            Cycling:proposal_.Cycling,
            weight:1
        }));
        if(sender.voteRounds>roundMax)
            roundMax=sender.voteRounds;
        sender.voteRounds+=1;
    }

    //计算投票结果
    function winningProposal() public view returns (Proposal[4] memory Proposal_){
        for(uint round=0;round<=roundMax;round++){
            uint weight_=0;
            for(uint i=0;i<proposals[round].length;i++){
                Proposal_[round].PassengerCars+=proposals[round][i].PassengerCars*proposals[round][i].weight;
                Proposal_[round].Motocycle+=proposals[round][i].Motocycle*proposals[round][i].weight;
                Proposal_[round].Bus+=proposals[round][i].Bus*proposals[round][i].weight;
                Proposal_[round].HeavyRail+=proposals[round][i].HeavyRail*proposals[round][i].weight;
                Proposal_[round].Walking+=proposals[round][i].Walking*proposals[round][i].weight;
                Proposal_[round].Cycling+=proposals[round][i].Cycling*proposals[round][i].weight;
                weight_+=proposals[round][i].weight;
            }
            Proposal_[round].PassengerCars/=weight_;
            Proposal_[round].Motocycle/=weight_;
            Proposal_[round].Bus/=weight_;
            Proposal_[round].HeavyRail/=weight_;
            Proposal_[round].Walking/=weight_;
            Proposal_[round].Cycling/=weight_;
        }
    }
}
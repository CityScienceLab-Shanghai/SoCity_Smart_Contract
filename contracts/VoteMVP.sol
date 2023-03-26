//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "./library/ABDKMathQuad.sol";
contract VoteMVP{
    
    int car_cost = 182; //g/km
    int bus_cost = 25; //g/km
    int heavy_rail_cost = 155; //g/km

    //1. 取消了新手期，换成了固定的target_allowance作为baseline, 并且前4周都不会改变
    //到第四周时，需要获取前四周的carbon_emission的平均值来update target_allowance, 之后每半年进行一次更新。
   
   //只能运行16个 variables
    struct Voter{
        int target_carbon_allowance; //当前的allowance, 如果为0，那么说明就是新来的
        int[] carbon_cost_per_week; //通过sensor来得到这周花费的碳消耗
        //int reputation_score;//不是确定值，需要用户输入，这部分只能用户知道，其他人不知道
        int carbon_coin; //1kg = 1coin
        int decreasedAllowancePercentage_; //allowance_settlement_voting中的这个变量
        //int Locked_governanceToken; //锁住的token
        //先暂时设计成：由chairperson来执行,之后会通过时间来控制
        int isVoted; //表示这一周是否投票过?，比如到下周需要重新投票的时候，isVoted又会变成0,表示可以重新投票
        int round;
        Travel_mode sensor_travel_mode; //出行方式(通过sensor得到的)
        Travel_mode expect_travel_mode; //期望的下周的出行方式(通过用户自己输入)
    }


    struct Travel_mode{
        int passenger_cars;
        int bus;
        int heavy_rail;
        int walking;
        int cycling;

    }

    //根据address来得到不同的Voter
    mapping(address => Voter) public voters;
    //address public chairperson;

    Voter[] public voters_; //投票的人数
    int initialTargetAllowance = 182; //g/km
    int fresh_round = 4;

    //int[] decreasedAllowancePercentage; //存储每一个不同user的decreasedAllowancePercentage
    int votingUser; //总人数
    address chairperson; //主席

    //msg.sender: 调用该contract的人
    constructor() public {
        chairperson = msg.sender;
    }



    
    //谁都可以加入还是需要审核？
    //level不应该自己输入，这部分之后需要修改
    //刚加入dao的时候才需要执行这个function
    function initialNewUser() public{
        require(voters[msg.sender].target_carbon_allowance == 0,"you've already exist!");
        Voter storage sender = voters[msg.sender];
        sender.target_carbon_allowance = initialTargetAllowance;
        sender.round = 0; //新手
        sender.isVoted = 0;
        //sender.reputation_score = 1;
        sender.carbon_coin = 0;
        votingUser += 1;
    }

    //通过sensor得到自己的每一种交通工具所消耗的km
    //需要前端获取用户的每个travel的值然后放到这里面
    function setTravelDataBySensor(Travel_mode memory _travel_mode) public {
        voters[msg.sender].sensor_travel_mode.passenger_cars = _travel_mode.passenger_cars;
        voters[msg.sender].sensor_travel_mode.bus = _travel_mode.bus;
        voters[msg.sender].sensor_travel_mode.heavy_rail = _travel_mode.heavy_rail;
        voters[msg.sender].sensor_travel_mode.walking = _travel_mode.walking;
        voters[msg.sender].sensor_travel_mode.cycling = _travel_mode.cycling;
    }

    //测试用的，之后会删除
    function TestExpectedDataByInput(Travel_mode memory _expect_mode) public {
        voters[msg.sender].expect_travel_mode.passenger_cars = _expect_mode.passenger_cars;
        voters[msg.sender].expect_travel_mode.bus = _expect_mode.bus;
        voters[msg.sender].expect_travel_mode.heavy_rail = _expect_mode.heavy_rail;
        voters[msg.sender].expect_travel_mode.walking = _expect_mode.walking;
        voters[msg.sender].expect_travel_mode.cycling = _expect_mode.cycling;
    }


    //之后的步骤，MVP阶段不涉及
    // function setExpectPassengerCars(int _passenger_cars) public {
    //     //还没有执行到 getDecreasedAllowancePercentage()
    //     require(voters[msg.sender].isVoted < 2, "you've already voted this week!");
    //     voters[msg.sender].expect_travel_mode.passenger_cars = _passenger_cars;
    // }

    // function setExpectBus(int _bus) public {
    //     require(voters[msg.sender].isVoted < 2, "you've already voted this week!");
    //     voters[msg.sender].expect_travel_mode.bus = _bus;
    // }

    // function setExpectHeavyRail(int _heavy_rail) public {
    //     require(voters[msg.sender].isVoted < 2, "you've already voted this week!");
    //     voters[msg.sender].expect_travel_mode.heavy_rail = _heavy_rail;
    // }

    // function setExpectWalking(int _walking) public {
    //     require(voters[msg.sender].isVoted < 2, "you've already voted this week!");
    //     voters[msg.sender].expect_travel_mode.walking = _walking;
    // }

    // function setExpectCycling(int _cycling) public {
    //     require(voters[msg.sender].isVoted < 2, "you've already voted this week!");
    //     voters[msg.sender].expect_travel_mode.cycling = _cycling;
    // }


    //计算每个用户的carbon_emission
    function calculateCurrentCarbonCost() public{
        Voter storage sender = voters[msg.sender];
        //还没有初始化
        require(voters[msg.sender].target_carbon_allowance != 0,"you have not initialize!");
        require(voters[msg.sender].isVoted == 0, "you cannot operate this function");
        //得到总花费km数
        int sum = (sender.sensor_travel_mode.passenger_cars+
                    sender.sensor_travel_mode.bus+
                    sender.sensor_travel_mode.heavy_rail+
                    sender.sensor_travel_mode.walking+
                    sender.sensor_travel_mode.cycling);
        
        require(sum != 0, "your sensor is empty, try to contact the chairperson XXXXXX");

        bytes16 carbon_quota = 0;
        int carbon_cost = 0;
        bytes16 carbon_cost_per_week = 0;
        bytes16 residual_carbon_quota = 0;

        //target_allowance * 总km数
        carbon_quota = ABDKMathQuad.mul(
            ABDKMathQuad.fromInt(sender.target_carbon_allowance),
            ABDKMathQuad.fromInt(sum)
        );
        //每种出行方式所消耗的碳排放*对应出行方式的km数
        carbon_cost = (sender.sensor_travel_mode.passenger_cars*car_cost+
                        sender.sensor_travel_mode.bus*bus_cost+
                        sender.sensor_travel_mode.heavy_rail*heavy_rail_cost);

        carbon_cost_per_week = ABDKMathQuad.div(ABDKMathQuad.fromInt(carbon_cost),ABDKMathQuad.fromInt(sum));
        residual_carbon_quota = ABDKMathQuad.div(ABDKMathQuad.sub(
        carbon_quota, ABDKMathQuad.fromInt(carbon_cost)),ABDKMathQuad.fromInt(1000));

        sender.carbon_cost_per_week.push(ABDKMathQuad.toInt(carbon_cost_per_week)); //添加该用户的这周的碳排放量
        sender.carbon_coin += ABDKMathQuad.toInt(residual_carbon_quota); //用户这周获取的carbon_coin
        sender.isVoted++; //表示该用户执行过该方法
        sender.round++;
    }

    
    //getAllowancePercentage,当前MVP阶段不考虑
    //如果反悔了需要撤销怎么办?-前端需要考虑
    // function getDecreasedAllowancePercentage() public{
    //     Voter storage sender = voters[msg.sender]; //这里为什么必须存储sender?

    //     //还没有初始化
    //     require(voters[msg.sender].target_carbon_allowance != 0,"you have not initialize!");
    //     require(voters[msg.sender].isVoted == 1, "you cannot operate this function");

    //      //得到下周期望的km
    //      //需要修改一下
    //     // require(sender.expect_travel_mode.passenger_cars != 0, "please input your passenger_cars");
    //     // require(sender.expect_travel_mode.motocycle != 0, "please input your motocycle");
    //     // require(sender.expect_travel_mode.bus != 0, "please input your bus");
    //     // require(sender.expect_travel_mode.heavy_rail != 0, "please input your heavy_rail");
    //     // require(sender.expect_travel_mode.walking != 0, "please input your walking");
    //     // require(sender.expect_travel_mode.cycling != 0, "please input your cycling");

    //     int sum = sender.expect_travel_mode.passenger_cars+
    //                 sender.expect_travel_mode.bus+
    //                 sender.expect_travel_mode.heavy_rail+
    //                 sender.expect_travel_mode.walking+
    //                 sender.expect_travel_mode.cycling;

    //     require(sum != 0, "your expect travel mode is empty, please go back to check input");

    //     //用户自己投票的下周的碳排放量
    //    bytes16 voting_carbon_allowance = ABDKMathQuad.div(ABDKMathQuad.fromInt(sender.expect_travel_mode.passenger_cars*car_cost+
    //                                 sender.expect_travel_mode.bus*bus_cost+
    //                                 sender.expect_travel_mode.heavy_rail*heavy_rail_cost),ABDKMathQuad.fromInt(100));

    //                 //得到下周的decreasedAllowancePercentage_是否下降或者上升
    //     sender.decreasedAllowancePercentage_ = ABDKMathQuad.toInt(
    //         ABDKMathQuad.mul(
    //             ABDKMathQuad.div(
    //                 ABDKMathQuad.sub(
    //                     ABDKMathQuad.fromInt(sender.target_carbon_allowance),
    //                     voting_carbon_allowance),
    //                 ABDKMathQuad.fromInt(sender.target_carbon_allowance)
    //             ), ABDKMathQuad.fromInt(100)
    //     ));

    //     //allowance-settlement-voting 位置的 decreasedAllowancePercentage
    //     //decreasedAllowancePercentage.push(sender.decreasedAllowancePercentage_); //添加当前用户的allowancePercentage
    //     voters_.push(sender);
    //     sender.isVoted++; //表示该用户执行过该方法
    // }


    //下一周建议的carbonAllowance,MVP不考虑
    // function ExpectCarbonAllowance() public{

    //     //还没有初始化
    //     require(voters[msg.sender].target_carbon_allowance != 0,"you have not initialize!");
    //     //这周已经投过票了
    //     require(voters[msg.sender].isVoted == 2, "you cannot operate this function");
    //     //如果没有计算allowance-settlement-voting 位置的 decreasedAllowancePercentage是没有办法进入该function的
    //     require(voters[msg.sender].decreasedAllowancePercentage_ != 0, "you have not get DecreasedAllowancePercentage!");

    //     Voter storage sender = voters[msg.sender]; //这里为什么必须存储sender?

    //     //计算achievement位置的 decreasedAllowancePercentage
    //     //每个用户weight的计算方法也是根据reputationScore来计算的
    //     bytes16 decreasedAllowancePercentage_ = 0;
    //     bytes16 sumReputationScore = 0;

    //     for(uint i = 0; i < voters_.length; i++){
    //         sumReputationScore = ABDKMathQuad.add(sumReputationScore,
    //         ABDKMathQuad.fromInt(voters_[i].reputation_score));
    //     }

    //     for(uint i = 0; i < voters_.length; i++){
    //             //算每个老手投票成员的权重
    //         decreasedAllowancePercentage_ = ABDKMathQuad.add(decreasedAllowancePercentage_,
    //             ABDKMathQuad.mul(
    //                 ABDKMathQuad.fromInt(voters_[i].reputation_score),
    //                 ABDKMathQuad.fromInt(voters_[i].decreasedAllowancePercentage_)
    //             )
    //         );
    //     }
        
    //     decreasedAllowancePercentage_ = ABDKMathQuad.div(decreasedAllowancePercentage_,sumReputationScore);

        
    //     bytes16 next_week_carbon_allowance = 0;
    //     bytes16 decreased_allowance = 0;
    //     bytes16 residual_allowance= 0;

    //      //并非第一次投票，那么需要target_carbon_allowance, 还有已经存在的governanceToken来计算这一周的碳消耗
    //     next_week_carbon_allowance = ABDKMathQuad.mul(
    //         ABDKMathQuad.fromInt(sender.target_carbon_allowance),
    //             ABDKMathQuad.sub(ABDKMathQuad.fromInt(1),
    //                 ABDKMathQuad.div(
    //                     decreasedAllowancePercentage_,
    //                     ABDKMathQuad.fromInt(100)
    //             )
    //         )
    //     );

    //     decreased_allowance = ABDKMathQuad.sub(
    //         ABDKMathQuad.fromInt(sender.target_carbon_allowance),
    //         next_week_carbon_allowance
    //     );

    //     residual_allowance = ABDKMathQuad.sub(
    //         ABDKMathQuad.fromInt(sender.target_carbon_allowance),
    //         ABDKMathQuad.fromInt(sender.carbon_cost_per_week)
    //     );

    //     //得到新的governanceToken
    //     sender.reputation_score += ABDKMathQuad.toInt(ABDKMathQuad.add(residual_allowance, decreased_allowance)); 
        
    //     sender.isVoted++; //表示该用户执行过该方法，执行到这这周就不能随便改动了。
    //     sender.round++; //这周投票结束

    // }

    //需要由chairperson来开启这个function
    function theNewRound(address _voter) public{
        //新一轮start, 这个时候需要用自己上一周所得到的target_carbon_allowance来进行计算
        //初始化需要计算的的所有值(reputation_score, target_allowance)
        Voter storage v = voters[_voter];
        require(v.target_carbon_allowance != 0,"you have not initialize!");
        require(msg.sender == chairperson, "only chairperson can use this function");
        v.isVoted = 0; //设置为0
        delete voters_; //今天的老手投票结束
        v.decreasedAllowancePercentage_ = 0; //设置为0
        delete v.sensor_travel_mode;
        delete v.expect_travel_mode;
        UpateUsersTargetAllowance(v); //看是否需要更新carbonAllowance
    }


    //每四周，每半年进行target_allowance的一次更新
    function UpateUsersTargetAllowance(Voter storage _voter) internal{
        int updateCarbonAllowance = 0;
        if(_voter.round == 4){
            //获得该用户这四周的carbonEmission
            bytes16 fourWeeksSumCarbonEmissons = 0;
            for(uint i = 0; i < _voter.carbon_cost_per_week.length;i++){
                fourWeeksSumCarbonEmissons = ABDKMathQuad.add(fourWeeksSumCarbonEmissons,
                ABDKMathQuad.fromInt(_voter.carbon_cost_per_week[i]));
            }
            //获取新的carbonAllowance
            updateCarbonAllowance = ABDKMathQuad.toInt(
                ABDKMathQuad.div(fourWeeksSumCarbonEmissons,
                ABDKMathQuad.fromUInt(_voter.carbon_cost_per_week.length)));
            //清空
            delete _voter.carbon_cost_per_week;
            _voter.target_carbon_allowance = updateCarbonAllowance; //更新用户的targetAllowance

        }
        if(_voter.round%24 == 0){
            //半年更新一次
            bytes16 halfYearSumCarbonEmissons = 0;
            for(uint i = 0; i < _voter.carbon_cost_per_week.length;i++){
                halfYearSumCarbonEmissons = ABDKMathQuad.add(halfYearSumCarbonEmissons,
                ABDKMathQuad.fromInt(_voter.carbon_cost_per_week[i]));
            }
            //获取新的carbonAllowance
            updateCarbonAllowance = ABDKMathQuad.toInt(
                ABDKMathQuad.div(halfYearSumCarbonEmissons,
                ABDKMathQuad.fromUInt(_voter.carbon_cost_per_week.length)));
            //清空
            delete _voter.carbon_cost_per_week;
            _voter.target_carbon_allowance = updateCarbonAllowance; //更新用户的targetAllowance
        }
    }
    
    
}


    //测试数据：
    //user1: r1: [123,4,1,23,5,23], [65,5,5,10,3,12]
    //user2: r1: [45,21,23,112,23,2], [23,12,12,50,2,1]
    //user3: r1: [100,0,2,59,2,1], [51,0,2,25,12,10]

    //user1: r2: [100,23,2,11,20,90], [50,5,2,3,6,34]
    //user2: r2: [40,30,32,60,22,12], [20,10,10,50,4,6]
    //user3: r2: [98,2,2,60,2,3], [60,0,2,10,4,24]

    //user1: r3: [99,21,4,20,25,23], [75,7,5,5,4,4]
    //user2: r3: [43,20,33,59,23,21], [20,10,15,40,4,11]
    //user3: r3: [80,0,20,40,4,4], [56,0,15,15,4,10]

    //user1: r4: [100,23,2,11,20,90], [78,5,2,3,6,6]
    //user2: r4: [40,30,32,60,22,12], [20,10,10,50,4,6]
    //user3: r4: [98,2,2,60,2,3], [80,0,2,10,4,4]

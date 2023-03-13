//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract vote{
    
    int car_cost = 192; //g/km
    int moto_cycle_cost = 103; //g/km
    int bus_cost = 105; //g/km
    int heavy_rail_cost = 41; //g/km

    //Q1: 需不需要delegate？
    //Q2: 是不是应该一部分移动到前端？比如：如果一个用户得到了当前计算的target_carbon_allowance
    //需要自己计划下一周怎么规划自己的交通工具的km数，那么用户可能会不断修改自己下周规划的km数，
    //或者他某一种类的交通工具km数输入错误，所以他需要重新输入等等情况，那么这一部分肯定不需要上链，而是用户自己模拟
    //Q3: 文档中计算的 Achievement: Decreased allowance percentage(%)中的权重计算一直都是固定的，应该是需要变化的
    //Q4: 精度问题，无法实现小数(y一定要注意小数，如果a = 0.x, 那么直接会截断变成0)
    //四个地方需要改: 新手保护期，前端

    //只能运行16个 variables
    struct Voter{
        //uint256 weight; //weight, weight会随着governance token值进行变化，这个之后再进行变化，先假设都为1
        //bool isDegelate;
        //address delegate;
        uint level; //设置的level
        int target_carbon_allowance; //当前的allowance, 如果为0，那么说明就是新来的
        int carbon_cost_per_week; //通过sensor来得到这周花费的碳消耗
        int governanceToken;//不是确定值，需要用户输入，这部分只能用户知道，其他人不知道
        int carbon_coin; //1kg = 1coin, 是否还需要一个最小单位？
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
        int motocycle;
        int bus;
        int heavy_rail;
        int walking;
        int cycling;

    }
    //此处六种出行方式需要改变成五种
    //根据address来得到不同的Voter
    mapping(address => Voter) public voters;
    //address public chairperson;
    int[5] suggestAllowance; //设置的不同level
    //设置不同的level,当前level只有5层

    Voter[] public voters_; //这一天投票的人的总数

    //int[] decreasedAllowancePercentage; //存储每一个不同user的decreasedAllowancePercentage
    int votingUser; //总人数
    address chairperson; //主席

    //msg.sender: 调用该contract的人
    constructor() public {
        chairperson = msg.sender;
        suggestAllowance[0] = 1523;
        suggestAllowance[1] = 1823;
        suggestAllowance[2] = 2123;
        suggestAllowance[3] = 2423;
        suggestAllowance[4] = 2723;
    }



    
    //谁都可以加入还是需要审核？
    //level不应该自己输入，这部分之后需要修改
    //刚加入dao的时候才需要执行这个function
    function initialNewUser(uint _level) public{
        require(voters[msg.sender].level == 0,"you've already exist!");
        Voter storage sender = voters[msg.sender];
        sender.level = _level-1;
        sender.isVoted = 0;
        sender.governanceToken = 1;
        sender.carbon_coin = 0;
        votingUser += 1;
    }

    //通过sensor得到自己的每一种交通工具所消耗的km
    //之后会修改，因为不应该自己手动输入
    function setTravelDataBySensor(Travel_mode memory _travel_mode) public {
        voters[msg.sender].sensor_travel_mode.passenger_cars = _travel_mode.passenger_cars;
        voters[msg.sender].sensor_travel_mode.motocycle = _travel_mode.motocycle;
        voters[msg.sender].sensor_travel_mode.bus = _travel_mode.bus;
        voters[msg.sender].sensor_travel_mode.heavy_rail = _travel_mode.heavy_rail;
        voters[msg.sender].sensor_travel_mode.walking = _travel_mode.walking;
        voters[msg.sender].sensor_travel_mode.cycling = _travel_mode.cycling;
    }

    //测试用的，之后会删除
    function TestExpectedDataByInput(Travel_mode memory _expect_mode) public {
        voters[msg.sender].expect_travel_mode.passenger_cars = _expect_mode.passenger_cars;
        voters[msg.sender].expect_travel_mode.motocycle = _expect_mode.motocycle;
        voters[msg.sender].expect_travel_mode.bus = _expect_mode.bus;
        voters[msg.sender].expect_travel_mode.heavy_rail = _expect_mode.heavy_rail;
        voters[msg.sender].expect_travel_mode.walking = _expect_mode.walking;
        voters[msg.sender].expect_travel_mode.cycling = _expect_mode.cycling;
    }


    //设置自己下周期望的小轿车km
    function setExpectPassengerCars(int _passenger_cars) public {
        //还没有执行到 getDecreasedAllowancePercentage()
        require(voters[msg.sender].isVoted < 2, "you've already voted this week!");
        voters[msg.sender].expect_travel_mode.passenger_cars = _passenger_cars;
    }

    //设置自己下周期望的摩托车km
    function setExpectMotoCycle(int _motocycle) public {
        require(voters[msg.sender].isVoted < 2, "you've already voted this week!");
        voters[msg.sender].expect_travel_mode.motocycle = _motocycle;
    }

    function setExpectBus(int _bus) public {
        require(voters[msg.sender].isVoted < 2, "you've already voted this week!");
        voters[msg.sender].expect_travel_mode.bus = _bus;
    }

    function setExpectHeavyRail(int _heavy_rail) public {
        require(voters[msg.sender].isVoted < 2, "you've already voted this week!");
        voters[msg.sender].expect_travel_mode.heavy_rail = _heavy_rail;
    }

    function setExpectWalking(int _walking) public {
        require(voters[msg.sender].isVoted < 2, "you've already voted this week!");
        voters[msg.sender].expect_travel_mode.walking = _walking;
    }

    function setExpectCycling(int _cycling) public {
        require(voters[msg.sender].isVoted < 2, "you've already voted this week!");
        voters[msg.sender].expect_travel_mode.cycling = _cycling;
    }


    //计算这周消耗的碳限额以及比较碳限额
    //为什么这里要使用uint
    //这三个函数之间的调用，每个用户每周只能调用一次，所以需要设计一下三个函数之间的调用
    //怎么样可以第二次round?
    //如果sensor当中的数据全部为空，那么就直接作废，不能参与投票

    //如果出现小数，那么一定要先扩大然后再除，以免出现0的情况
    function calculateCurrentCarbonCost() public{
        Voter storage sender = voters[msg.sender]; //这里为什么必须存储sender?
        //还没有初始化
        require(voters[msg.sender].level != 0,"you have not initialize!");
        require(voters[msg.sender].isVoted == 0, "you cannot operate this function");
        //得到总花费km数
        int sum = (sender.sensor_travel_mode.passenger_cars+
                    sender.sensor_travel_mode.motocycle+
                    sender.sensor_travel_mode.bus+
                    sender.sensor_travel_mode.heavy_rail+
                    sender.sensor_travel_mode.walking+
                    sender.sensor_travel_mode.cycling);
        
        require(sum != 0, "your sensor is empty, try to contact the chairperson XXXXXX");

        //为什么索引为uint
        int carbon_quota = (suggestAllowance[sender.level]/10)*sum;
        int carbon_cost = (sender.sensor_travel_mode.passenger_cars*car_cost+
                            sender.sensor_travel_mode.motocycle*moto_cycle_cost+
                            sender.sensor_travel_mode.bus*bus_cost+
                            sender.sensor_travel_mode.heavy_rail*heavy_rail_cost);
        
        //这些参数一定会>0
        int carbon_cost_per_week = carbon_cost/sum;  //sensor检测到的你这周的碳排放
        int residual_carbon_quota = (carbon_quota - carbon_cost)/1000;

        // //这周sensor检测到的碳排放小于上周用户自己制定的碳排放量，那么用户得到奖励
        // if(carbon_cost_per_week < sender.target_carbon_allowance){
        //     sender.governanceToken += sender.Locked_governanceToken; //得到新的governanceToken的奖励
        // }
        // sender.Locked_governanceToken = 0; //清零
        sender.carbon_cost_per_week = carbon_cost_per_week; //记录sensor检测到的你这周的碳排放
        sender.carbon_coin += residual_carbon_quota; //1kg = 1coin，但是solidity没有小数,这样计算会直接少了精度，是否需要最小单位？
        sender.isVoted++; //表示该用户执行过该方法
        

    }

    
    //getAllowancePercentage
    //如果反悔了需要撤销怎么办?-前端需要考虑
    function getDecreasedAllowancePercentage() public{
        Voter storage sender = voters[msg.sender]; //这里为什么必须存储sender?

        //还没有初始化
        require(voters[msg.sender].level != 0,"you have not initialize!");
        require(voters[msg.sender].isVoted == 1, "you cannot operate this function");

         //得到下周期望的km
         //需要修改一下
        // require(sender.expect_travel_mode.passenger_cars != 0, "please input your passenger_cars");
        // require(sender.expect_travel_mode.motocycle != 0, "please input your motocycle");
        // require(sender.expect_travel_mode.bus != 0, "please input your bus");
        // require(sender.expect_travel_mode.heavy_rail != 0, "please input your heavy_rail");
        // require(sender.expect_travel_mode.walking != 0, "please input your walking");
        // require(sender.expect_travel_mode.cycling != 0, "please input your cycling");

        int sum = sender.expect_travel_mode.passenger_cars+
                    sender.expect_travel_mode.motocycle+
                    sender.expect_travel_mode.bus+
                    sender.expect_travel_mode.heavy_rail+
                    sender.expect_travel_mode.walking+
                    sender.expect_travel_mode.cycling;

        require(sum != 0, "your expect travel mode is empty, please go back to check input");

        //用户自己投票的下周的碳排放量
        int voting_carbon_allowance = (sender.expect_travel_mode.passenger_cars*car_cost+
                                    sender.expect_travel_mode.motocycle*moto_cycle_cost+
                                    sender.expect_travel_mode.bus*bus_cost+
                                    sender.expect_travel_mode.heavy_rail*heavy_rail_cost)/100;

        int a = 0;
        int b = 0;
        //第一次投票，没有之前的数据
        if(sender.target_carbon_allowance == 0){
            //使用一开始的level级
            //得到下周的decreasedAllowancePercentage_是否下降或者上升
            //正数代表上升,负数代表下降
            //不确定相除是否为0.x, 那么就放大倍数
            a = (suggestAllowance[sender.level]/10) - voting_carbon_allowance;
            b = a*100/(suggestAllowance[sender.level]/10); 
            sender.decreasedAllowancePercentage_ = b;
            
        }else{
            //并非第一次投票，那么需要target_carbon_allowance, 还有已经存在的governanceToken来计算这一周的碳消耗
            //得到下周的decreasedAllowancePercentage_是否下降或者上升
            a = sender.target_carbon_allowance - voting_carbon_allowance;
            b = a*100/sender.target_carbon_allowance;
            sender.decreasedAllowancePercentage_ = b;
        }

        //allowance-settlement-voting 位置的 decreasedAllowancePercentage
        //decreasedAllowancePercentage.push(sender.decreasedAllowancePercentage_); //添加当前用户的allowancePercentage
        voters_.push(sender); //添加新投票的用户进入
        sender.isVoted++; //表示该用户执行过该方法
    }

    //下一周建议的carbonAllowance

    //这部分需要统一结算，比如得到这周的所有人员都投过票了，在一个统一的时间进行结算
    function ExpectCarbonAllowance() public{
        //还没有初始化
        require(voters[msg.sender].level != 0,"you have not initialize!");
        //这周已经投过票了
        require(voters[msg.sender].isVoted == 2, "you cannot operate this function");

        //如果没有计算allowance-settlement-voting 位置的 decreasedAllowancePercentage是没有办法进入该function的
        require(voters[msg.sender].decreasedAllowancePercentage_ != 0, "you have not get DecreasedAllowancePercentage!");

        Voter storage sender = voters[msg.sender]; //这里为什么必须存储sender?

        //计算achievement位置的 decreasedAllowancePercentage
        //每个用户weight的计算方法也是根据governance_token来计算的
        int decreasedAllowancePercentage_ = 0;


        int sumGovernanceToken = 0; //得到总的投票人数的token
        //这里i要设置为uint,why?
        //难道是.length的问题?
        for(uint i = 0; i < voters_.length; i++){
            sumGovernanceToken += voters_[i].governanceToken;
        }
        for(uint i = 0; i < voters_.length; i++){
            //算每个投票成员的权重
            decreasedAllowancePercentage_ += voters_[i].governanceToken*voters_[i].decreasedAllowancePercentage_;
        }
        decreasedAllowancePercentage_/=sumGovernanceToken;

        // for(uint i = 0; i < decreasedAllowancePercentage.length; i++){
        //     //这里设置的是每个用户的weight = 1; 后期需要根据每个用户的weight来进行计算,还需要修改这一部分
        //     decreasedAllowancePercentage_ += decreasedAllowancePercentage[i];
        // }
        // //如果和weight有关，那么之后这一部分会修改
        // decreasedAllowancePercentage_/=int(decreasedAllowancePercentage.length);



        int next_week_carbon_allowance = 0;
        int decreased_allowance = 0;
        int residual_allowance = 0;
        //第一次投票，没有之前的数据
        if(sender.target_carbon_allowance == 0){
            //得到下周的carbon_allowance
            //防止a为0.x, 那么直接就会变成0
            next_week_carbon_allowance = suggestAllowance[sender.level]/10 - ((suggestAllowance[sender.level]/10)*decreasedAllowancePercentage_)/100;
            decreased_allowance = (suggestAllowance[sender.level]/10) - next_week_carbon_allowance;
            residual_allowance = (suggestAllowance[sender.level]/10) - sender.carbon_cost_per_week;
        }else{
            //并非第一次投票，那么需要target_carbon_allowance, 还有已经存在的governanceToken来计算这一周的碳消耗
            next_week_carbon_allowance = sender.target_carbon_allowance - (sender.target_carbon_allowance*decreasedAllowancePercentage_)/100;
            decreased_allowance = sender.target_carbon_allowance - next_week_carbon_allowance;
            residual_allowance = sender.target_carbon_allowance - sender.carbon_cost_per_week;
        }
        
        sender.target_carbon_allowance = next_week_carbon_allowance; 
        //之后需要修改
        //得到新的governanceToken
        int governanceToken = (residual_allowance + decreased_allowance);
        sender.governanceToken += governanceToken; //重新产生的governanceToken
        sender.isVoted++; //表示该用户执行过该方法，执行到这这周就不能随便改动了。
        sender.round++; //这周投票结束

    }

    //需要由chairperson来开启这个function
    //每个voters都需要统一一起更新，以防删除decreasedAllowancePercentage：
    function theNewRound(address _voter) public{
        //新一轮start, 这个时候需要用自己上一周所得到的target_carbon_allowance来进行计算
        //初始化需要计算的的所有值(除了token, level)
        Voter storage v = voters[_voter];
        require(v.level != 0,"you have not initialize!");
        require(msg.sender == chairperson, "only chairperson can use this function");
        v.isVoted = 0; //设置为0
        v.carbon_cost_per_week = 0;
        // for(uint i = 0; i < decreasedAllowancePercentage.length; i++){
        //     if(decreasedAllowancePercentage[i] == v.decreasedAllowancePercentage_){
        //         decreasedAllowancePercentage[i] = 0; //消除该用户上一周的值
        //     }
        // }
        //delete decreasedAllowancePercentage; //直接删除
        delete voters_;
        v.decreasedAllowancePercentage_ = 0; //设置为0
        delete v.sensor_travel_mode;
        delete v.expect_travel_mode;
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


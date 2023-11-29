local alpha = 0.15
local beta = 4      --BPR函数系数
local t0 = {100, 200}       --零流阻抗
local U = {50,100}      ----容量

function BPR(t0, f, U)      --求BPR函数值
    local t = t0*(1 + alpha*(f/U)^beta)
    return t
end
local n = 1     --迭代次数

-- frankwolfe解法

function frank_wolfe(q)
    local f = {q, 0}  -- 初始流量分配
    local pref = {0, 0}
    local circulate = true      --循环是否结束
    local n = 0     --迭代次数
    
    -- BPR函数的导数
    function tyler(t0, x, U, prex) -- 使用泰勒展开近似的总行程时间计算
        function BPR_Derivative(t0, f, U)       --使用泰勒级数近似计算总旅行时间时引用
            if f == 0 then
                return 0
            else
                return t0 * alpha * beta * ((f / U) ^ (beta - 1)) / U
            end
        end
        
        local sumT = 0 --初始化总时间
        for i = 1, #x do  --遍历所有的路段
            local t_a = BPR(t0[i], prex[i], U[i])
            local t_a_prime = BPR_Derivative(t0[i], prex[i], U[i])
            sumT = sumT + t_a * x[i] + 0.5 * t_a_prime * (x[i]^2 - prex[i]^2)
        end
        return sumT
    end
    
    function new_solution(x, s, gamma)      --更新流量
        local newX = {}
        for i = 1, #x do
            newX[i] = x[i] + gamma * (s[i] - x[i])
        end
        return newX
    end

    -- 二分法搜索步长（借鉴）
    function binarySearchForStepSize(x, x_star, t0, U)
        local low = 0
        local high = 1
        local lambda, mid
        local epsilon = 1e-8  -- 定义收敛精度
    
        while high - low > epsilon do
            mid = (low + high) / 2
            local grad = 0

            for i = 1, #x do
                local x_new = x[i] + mid * (x_star[i] - x[i])
                grad = grad + (x_star[i] - x[i]) * BPR(t0[i], x_new, U[i])
            end

            if grad > 0 then
                high = mid
            else
                low = mid
            end
        end

        lambda = (low + high) / 2
        return lambda
    end
    
    local valuep = tyler(t0, f, U, pref)

    while circulate do
        local t = {}        --各线段行驶时间
        for i = 1, #f do    -- 初始化
            t[i] = BPR(t0[i], f[i], U[i])
        end

        local x = {0, 0}    --tyler的最优解
        local minf = 1
        for i = 2, #f do       --求最优解
            if t[i] <= t[minf] then
                minf = i
            end
        end
        x[minf] = q     --赋值

        local gamma = binarySearchForStepSize(f, x, t0, U)      -- 使用二分法搜索最优步长

        pref = {f[1], f[2]}     -- 更新各线段的流量
        f = new_solution(f, x, gamma)

        local valuez = tyler(t0, f, U, pref)        -- 验证是否收敛
        if string.format("%.4f", valuez) == string.format("%.4f", valuep) then
            circulate = false
        else
            valuep = valuez
            n = n + 1
        end
    end
    
    --输出结果
    print("frank-wolfe的第", n, "次迭代结果为")
    print("a路线的流量为", f[1], "b路线的流量为", f[2])
end

--增量分配法

function incremental_assignment_method(q)
    local N = 50        --增量范围
    local demand = q
    local f = {0,0}
    local t = {}
    for i = 1, #f do
        f[i] = 0
        t[i] = BPR(t0[i], f[i], U[i])
    end
    local circulate = true      --循环是否结束
    
    while circulate do      --开始迭代
        if t[1] < t[2] then
                f[1] = f[1]+ U[1]/N
                q = q - U[1]/N
        else
            if q > U[2]/N then
                f[2] = f[2] + U[2]/N
                q = q - U[2]/N
            else
                f[2] = f[2] + q
                q = 0
            end
        end
        for i = 1, #f do
            t[i] = BPR(t0[i], f[i], U[i])
        end
        if q == 0 then
            circulate = false
            print("增量分配法的结果为")
            print("a路线的流量为", f[1], "b路线的流量为", f[2])
        end
    end
end

--连续平均法

function MSA(q)
    local theta = 1
    local circulate = true      --循环是否结束
    local f = {0,0}
    local t = {}
    local logit_f = {}
    
    function logit_prob(logit_t,t)      --logit分配模型
        local sum = 0
        for i = 1, #t do
            sum = sum + math.exp(-theta*t[i])
        end
        return math.exp(-theta*logit_t) / sum
    end
    
    for i = 1, #f do        --初始化
        f[i] = q/2
        t[i] = BPR(t0[i], f[i], U[i])
        logit_f[i] = logit_prob(t[i], t) * q
    end

    function next_f(x,y,I)      --更新流量
        local f =  x + 1/I*(y-x)
        return string.format("%.2f", f)
    end
            
    while circulate do
        local nextf = {}
        for i = 1, #f do
            nextf[i] = next_f(f[i],logit_f[i],n)
        end

        if f[1] == nextf[1] and f[2] == nextf[2] then
            print("连续平均法的第", n, "次迭代结果为")
            print("a路线的流量为", f[1], "b路线的流量为", f[2])
            circulate = false
        else
            n = n + 1
            for i = 1, #f do
                f[i] = nextf[i]
                t[i] = BPR(t0[i], f[i], U[i])
                logit_f[i] = logit_prob(t[i], t) * q
            end
        end
    end
end

frank_wolfe(100)
incremental_assignment_method(100)
MSA(100)
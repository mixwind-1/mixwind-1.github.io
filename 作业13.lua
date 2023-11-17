scene.setenv({camtype='ortho'})
local obj = scene.addobj('/res/world_countries.geojson')
local netgis = scene.addobj('simplemap.geojson')
local n = 1

--把地图的国家名字和颜色标记出来

for i,country in ipairs(obj:getchildren()) do    -- 
    local data = country:getdata()   -- 获取国家信息
    local xsum, ysum, zsum = 0, 0, 0    -- 设置坐标点的和
    local centerx, centery, centerz = {''}, {''}, {''}
    local pointsnum = 0      -- 初始化点的数量和点的坐标

    for j, land in ipairs(country:getchildren()) do    --国家的地块
        local points = land:getvertices()   -- 获得国家地块的边界上的顶点
        land:setmat({color=string.format('#bfd8dd'), opacity = 0.9})  -- 设置国家地块的颜色和透明度  
        pointsnum = pointsnum + #points /3   -- 记录国家边界上点的个数
        for k = 1, #points, 3 do  
            xsum = xsum + points[k]     -- 把每个地块的点总和起来
            ysum = ysum + points[k+1]
            zsum = zsum + points[k+2]
        end
    end
    
    centerx = xsum / pointsnum   -- 求均值
    centery = ysum / pointsnum
    centerz = zsum / pointsnum
    
    local label = scene.addobj('label', {text = data['NAME'], color = 'black', size = 1})
    label:setpos(centerx, centery, centerz)   -- 添加国家名字
end

----绘制航线并读取信息

local links = {}   --定义连接表格
n = 1
local node = 0
for i, feature in ipairs(netgis:getchildren()) do    --遍历图形数据
    local center_x, center_y = 0, 0   --求均值
    local islink   --判断是否为链接
    
    for j, part in ipairs(feature:getchildren()) do   --遍历图形所有部分
        local points = part:getvertices()
        for k = 1, #points, 3 do
            center_x, center_y = center_x + points[k], center_y + points[k+1]
        end
        center_x, center_y = center_x/#points*3, center_y/#points*3 + 1   --求均值
        islink = #points > 3   --标识链接
    end
    
    local data = feature:getdata()   --得到图形数据
    local lclr = islink and 'blue' or'red'   --设置颜色
    local label = scene.addobj('label', {text=data['ID'], color=lclr, size=2.5}) 
    label:setpos(center_x, center_y, 0)   --设置标签
    
    --   如果是航线，则读取信息
    if islink then
        table.insert(links, {id=data['ID'], o=data['O'], d=data['D'], w=data['W'], c=data['C']})
        n = n + 1
    else
        node = node + 1
    end
end

--连续最短路径问题

local preid = {''}      --溯前点
local marked = {}       --是否标记
local shortest_path = {}        --最短路径
local link_o, link_d, link_dis, link_c = {''}, {''}, {''}, {''}     --各航线段的信息
local d = {}        --最短路径长度
local pred = {}     --之前最短路径长度

for N = 1, node do      --初始化各点的信息
    pred[N] = 1e9
    d[N] = 0
end

for i = 1, #links do        --信息录入
    link_o[i] = tonumber(links[i].o)
    link_d[i] = tonumber(links[i].d)
    link_dis[i] = tonumber(links[i].w)
    link_c[i] = tonumber(links[i].c)
end

function find_shortest_path(startid, endid)  --用标号法求各点最短距离
    pred[startid] = 0
    aimedpath = {}
    local crtid = startid
    for N = 1, node do 
        marked[N] = false
        preid[N] = -1
    end
    marked[startid] = true --将起点进行标记
    while crtid ~= endid do
        for linkid = 1, #links do
            local linko = link_o[linkid]
            local linkd = link_d[linkid]
            local linkdis = link_dis[linkid]
            local linkc = link_c[linkid]
            if linkc ~= 0 then
                if linkc ~= 0 then
                    if linko == crtid then
                        local tmpid = linkd
                        if pred[crtid] + linkdis < pred[tmpid] then
                            pred[tmpid] = pred[crtid] + linkdis
                            preid[tmpid] = crtid
                        end
                    end
                    if linkd == crtid  then		--如果与当前节点邻接
                        local tmpid = linko				--并且另一端点的最短距离较大
                        if pred[crtid] + linkdis < pred[tmpid] then
                            pred[tmpid] = pred[crtid] + linkdis
                            preid[tmpid] = crtid		--修改另一端点的最短距离和前溯节点
                        end
                    end
                end
            end
        end
    
        crtid = endid
        for nodeid = 1, node do
            if not marked[nodeid] and pred[nodeid] < pred[crtid] then
                crtid = nodeid
            end
        end
        marked[crtid] = true
    end
    
    --打印路线
    local pointid = endid
    while pointid ~= startid do
        table.insert(aimedpath, 1, pointid)
        pointid = preid[pointid]
    end
    table.insert(aimedpath, 1, startid)
    shortest_path = aimedpath
end

function model_solve (startid,endid,num)        --建立函数
    local b = num       --运输量
    local ifend = true      --循环是否结束
    n = 1       --记录循环次数
    local flow = {}     --记录各线段流量情况
    local Q = 0     --流量成本计算
    find_shortest_path(startid, endid)      --先进行第一次最短路搜索
    for i = 1, #links do      --初始化flow
        flow[i] = 0
    end
    
    while ifend do      --开始进行迭代
        print(table.concat(link_o, "> "),",c",table.concat(link_c, "> "),",dis",table.concat(link_dis, "> "),",d",table.concat(d, "> "))
        local f = 1e9      --设置最短路上的最大流量
        
        for i = 1, #shortest_path do        --遍历最短路上各点以寻找最大流量
            for n = 1, #links do
                if link_o[n] == shortest_path[i] and link_d[n] == shortest_path[i+1] then
                    if link_c[n] < f then     --如果容量受限
                        f = link_c[n]
                    end
                end
            end
        end 
        
        for i = 1, node do        --遍历最短路上各点以更新d值
            d[i] = d[i] + pred[i]        --设置各点最短路径长度
            pred[i] = d[i]
        end
        
        for i = 1, #shortest_path-1 do      --更新容量
            for n = 1, #links do
                if link_o[n] == shortest_path[i] and link_d[n] == shortest_path[i+1] then
                    link_c[n] = link_c[n] - f
                    flow[n] = flow[n] + f
                end
            end
        end
        
        for i = 1, node do
            for n = 1, #links do
                if link_o[n] == i then
                    local ido, idd = link_o[n], link_d[n]
                    link_dis[n] = link_dis[n] + d[ido] - d[idd]
                    if link_c[n] == 0 then      --如果容量达到最大
                        link_c[n] = f
                        local nodeid = link_o[n]
                        link_o[n] = link_d[n]
                        link_d[n] = nodeid
                    end
                end
            end
        end
        
        if b > f then
            b = b - f
        else
            b = 0
        end
        if b == 0 then
            ifend = false
        end
        print("第",n,"次循环结果：")
        print(startid,"到",endid,"的最短路径为：",table.concat(shortest_path, "> "))
        n = n + 1
        find_shortest_path(startid, endid)
    end
    for i = 1, node do
        for n = 1, #links do
            local distance = tonumber(links[n].w)
            if link_o[n] == i then
                Q = Q + distance*flow[n]
            end
        end
    end
    print("从",startid,"到",endid,"的各航线流量为",table.concat(flow, "> "),",","流量成本为",Q)
end

model_solve (1,4,4)

scene.render()


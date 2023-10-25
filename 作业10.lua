scene.setenv({camtype='ortho'})
local obj = scene.addobj('/res/world_countries.geojson')
local netgis = scene.addobj('map.geojson')
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

--确定各航线权重

local distance = {''}
for i,lines in ipairs(netgis:getchildren()) do		--遍历所有航线
    for j, line in ipairs(lines:getchildren()) do	--遍历每条航段
        local pointnum, lat_rad, lon_rad, radian = -1, 0, 0, 0
        local x, y, z = {''}, {''}, {''}
        local r = 6371.00            -- 地球的半径
        local dis = 0
        local v = line:getvertices()
        -- 把每个点的经纬度转换为球面上的坐标点
        for k = 1 , #v, 3 do
            lat_rad = math.rad(v[k])  
            lon_rad = math.rad(v[k+1])
            pointnum = pointnum + 1
            -- 计算x、y、z坐标  
            x[(k+2)/3] = r * math.cos(lat_rad) * math.cos(lon_rad)
            y[(k+2)/3] = r * math.cos(lat_rad) * math.sin(lon_rad)
            z[(k+2)/3] = r * math.sin(lat_rad)
        end
        -- 求两点间的弧度，计算距离并累加得到结果
        for k = 1, pointnum do
            radian = math.acos((2*r*r - ((x[k]-x[k+1])*(x[k]-x[k+1])+(y[k]-y[k+1])*(y[k]-y[k+1])+(z[k]-z[k+1])*(z[k]-z[k+1]))) / (2*r*r))
            dis = dis + radian * r 
        end
        if dis ~= 0 then
            distance[n] = dis
            n = n + 1
        end
    end
end

----绘制航线并读取信息

local links = {}   --定义连接表格
n = 1
local node = -3
for i, feature in ipairs(netgis:getchildren()) do    --遍历图形数据
    local center_x, center_y = 0, 0   --求均值
    local islink   --判断是否为链接
    
    for j, part in ipairs(feature:getchildren()) do   --遍历图形所有部分
        local points = part:getvertices()
        for k = 1, #points, 3 do
            center_x, center_y = center_x + points[k], center_y + points[k+1]
        end
        center_x, center_y = center_x/#points*3, center_y/#points*3 + 3   --求均值
        islink = #points > 3   --标识链接
    end
    
    local data = feature:getdata()   --得到图形数据
    local lclr = islink and 'blue' or'red'   --设置颜色
    local label = scene.addobj('label', {text=data['ID'], color=lclr, size=2.5}) 
    label:setpos(center_x, center_y, 0)   --设置标签
    
    if islink then
        table.insert(links, {id=data['ID'], o=data['O'], d=data['D'], dis=distance[n]})
        n = n + 1
    else
        node = node + 1
    end
end

local stpdis = {''}
local preid = {''}
local marked = {}
local shortest_path = {}
local aimedpath ={''}
for N = 1, node do
    marked[N] = false
    stpdis[N] = 1e9
    preid[N] = -1
end

function find_shortest_path(startid, endid)  --用标号法求各点最短距离

    stpdis[startid] = 0
    local crtid = startid
    marked[startid] = true --将起点进行标记
    while crtid ~= endid do
        for linkid = 1, #links do
            local linko = tonumber(links[linkid].o)
            local linkd = tonumber(links[linkid].d)
            local linkdis = tonumber(links[linkid].dis)
            if linko == crtid then
                tmpid = linkd
                if stpdis[crtid] + linkdis < stpdis[tmpid] then
                    stpdis[tmpid] = stpdis[crtid] + linkdis
                    preid[tmpid] = crtid
                end
            end
            if linkd == crtid  then		--如果与当前节点邻接
                tmpid = linko				--并且另一端点的最短距离较大
                if stpdis[crtid] + linkdis < stpdis[tmpid] then
                    stpdis[tmpid] = stpdis[crtid] + linkdis
                    preid[tmpid] = crtid		--修改另一端点的最短距离和前溯节点
                end
            end
        end
    
        crtid = endid
        for nodeid = 1, node do
            if not marked[nodeid] and stpdis[nodeid] < stpdis[crtid] then
                crtid = nodeid
            end
        end
        marked[crtid] = true
    end
    
    --打印路线
    local pointid = endid
    while pointid ~= startid do
        table.insert(shortest_path, 1, pointid)
        pointid = preid[pointid]
    end
    table.insert(shortest_path, 1, startid)
    print(startid,"到",endid,"的最短路径为：",table.concat(shortest_path, "> "),"    ","长度为",stpdis[endid])
end
scene.render()

find_shortest_path(3,19)
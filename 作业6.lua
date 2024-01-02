scene.setenv({camtype='ortho'})
local obj = scene.addobj('/res/world_countries.geojson')

local China_points = {''}  
local cpointsnum = 0    -- 中国的顶点坐标和顶点个数

local color = {'#ff9274','#ffc99a','#bfd8dd'}   -- 中国的颜色，符合要求国家的颜色，不符合要求国家的颜色

-- 获得中国的顶点坐标并给地图上色
for i,country in ipairs(obj:getchildren()) do
    local data = country:getdata()   -- 获取国家信息
    if data['NAME'] == "China" then   -- 把中国的顶点坐标储存起来
        for j, land in ipairs(country:getchildren()) do  
            points = land:getvertices()
            for k = 1, #points do
                China_points[k] = math.floor(points[k])
                cpointsnum = cpointsnum + 1
            end
        end
    end
    --先把地图颜色涂上
    for j, land in ipairs(country:getchildren()) do
        land:setmat({color=string.format(color[3]), opacity = 0.9})
    end
end

--求地图名字放置的坐标
for i,country in ipairs(obj:getchildren()) do
    local data = country:getdata()
    local pointsnum = 0   -- 把每个地块的个数总和
    local centerx, centery, centerz = 0, 0, 0
    local export, import = tonumber(data['EXPORT']), tonumber(data['IMPORT'])
    local xsum, ysum, zsum = 0, 0, 0    -- 设置坐标点的和
    local adjacent = 0 --判断是否接壤
    
    -- 求地图名字放置的坐标 
    for j, land in ipairs(country:getchildren()) do
        local points = land:getvertices()   -- 获得国家地块的边界上的顶点
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
    
    --定义函数把国家名字添加到地块上
    function test(pointnum, x, y, z)    
        if pointnum > 1 then   --按点的个数设置名字大小
            if pointnum > 70 then
                if pointnum > 150 then
                    if pointnum > 200 then
                        local label = scene.addobj('label', {text = data['NAME'], color = 'black', size = 5})
                        label:setpos(x, y, z)   -- 添加国家名字
                    else
                        local label = scene.addobj('label', {text = data['NAME'], color = 'black', size = 3})
                        label:setpos(x, y, z)   -- 添加国家名字
                    end
                else
                    local label = scene.addobj('label', {text = data['NAME'], color = 'black', size = 2})
                    label:setpos(x, y, z)   -- 添加国家名字
                end
            else
                local label = scene.addobj('label', {text = data['NAME'], color = 'black', size = 1})
                label:setpos(x, y, z)   -- 添加国家名字
            end
        end
    end
    
    if data['NAME'] == "China" then   -- 把中国涂色
        for j, land in ipairs(country:getchildren()) do  
            points = land:getvertices()
            land:setmat({color=string.format(color[1]), opacity = 0.9})
        end
        test(pointsnum,centerx,centery,centerz)
    end
    
-- 设置函数来判断是否接壤
    function adjacency(x,y,z)
        local ad = 0    -- 先假设不接壤
        local cx, cy, cz = 0, 0, 0   -- 中国的顶点坐标
        for m = 1, cpointsnum, 3 do
            cx = China_points[m]
            cy = China_points[m+1]
            cz = China_points[m+2]
            if cx == math.floor(x) and cy == math.floor(y) and cz == math.floor(z) then   -- 如果接壤
                ad = 1
                break
            end
        end
        return ad
    end
    
-- 判断是否进口大于出口
    if import > export and data['NAME'] ~= "China" then
        for j, land in ipairs(country:getchildren()) do
            if adjacent == 1 then
                break
            else
                local points = land:getvertices()
                for k = 1, #points, 3 do
                    adjacent = adjacency(points[k],points[k+1],points[k+2])
                    if adjacent == 1 then
                        break
                    end
                end
            end
        end
        
        if adjacent == 1 then
            for j, land in ipairs(country:getchildren()) do
                land:setmat({color=string.format(color[2]), opacity = 0.9})
            end
            test(pointsnum,centerx,centery,centerz)
            print(data['NAME'], ", export:", data['EXPORT'], ", import:", data['IMPORT'])   -- 输出国家的出口进口信息
        end
    end
end
scene.render()
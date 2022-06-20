module DAQenvconds

using PyCall
using AbstractDAQs
import Dates: DateTime, now
import DataStructures: OrderedDict
export EnvConds, daqconfigdev, daqconfig, daqstop, daqacquire
export daqstart, daqread, samplesread, isreading
export daqchannels, numchannels, devname, devtype
export readpressure, readpresstemp, readhumidity, readhumtemp, readtemp
export daqclear, daqstatus

mutable struct EnvConds <: AbstractDAQ
    devname::String
    ip::String
    port::Int32
    server::PyObject
    conf::DAQConfig
    channames::Vector{String}
    chanidx::OrderedDict{String,Int}
    time::DateTime
end

AbstractDAQs.devtype(dev::EnvConds) = "EnvConds"

function EnvConds(devname, ip, port=9539)
    xmlrpc = pyimport("xmlrpc.client")
    server = xmlrpc.ServerProxy("http://$ip:$port")
    conf = DAQConfig(devname=devname, ip=ip, model="EnvConds")

    channames = server["channels"]()
    chanidx = OrderedDict{String,Int}()
    for (i,ch) in enumerate(channames)
        chanidx[ch] = i
    end
    conf.fpars["time"] = server["daqtime"]()
    
    EnvConds(devname, ip, port, server, conf,
             channames, chanidx,  now())
end


function AbstractDAQs.daqaddinput(dev::EnvConds, chans::AbstractVector{<:String})
    achans = dev.server["availablechannels"]()

    for ch in chans
        if ch ∉ achans
            error("Channel $ch not available!")
        end
    end

    dev.server["addinput"](chans)

    return
    
end

function AbstractDAQs.daqaddinput(dev::EnvConds, chans::AbstractVector{<:Integer})
    achans = dev.server["availablechannels"]()
    cmin, cmax = extrema(chans)
    
    if cmin < 1 || cmax > length(achans)
        error("Channel numbers should be between 1 and $(length(achans))!")
    end
    
    schans = achans[chans]
    
    dev.server["addinput"](schans)
    
    dev.channames = schans
    chanidx = OrderedDict{String,Int}()
    for (i,ch) in enumerate(dev.channames)
        chanidx[ch] = i
    end
    dev.chanidx = chanidx
    return
    
end

AbstractDAQs.daqconfigdev(dev::EnvConds; time=1) = dev.server["daqtime"](time)

AbstractDAQs.daqconfig(dev::EnvConds; time=1) = dev.server["daqtime"](time)


function AbstractDAQs.daqstart(dev::EnvConds)
    dev.time = now()
    dev.server["start"]()
end

function AbstractDAQs.daqchannels(dev::EnvConds)
    dev.channames = dev.server["channels"]()
    chanidx = OrderedDict{String,Int}()
    for (i,ch) in enumerate(dev.channames)
        chanidx[ch] = i
    end
    dev.chanidx = chanidx
    return dev.channames
end

AbstractDAQs.numchannels(dev::EnvConds) = length(dev.channames)


function parse_response(E)
    
    if ndims(E) == 2
        nch = size(E,2)-1
        nframes = size(E,1)
        X = zeros(nch, nframes)
        for i in 1:nframes
            for k in 1:nch
                X[k,i] = E[i,k+1]
            end
        end
        return X
    else
        nframes = length(E)
        nch = length(E[1])-1
        X = zeros(nch, nframes)
        for i in 1:nframes
            for k in 1:nch
                X[k,i] = E[i][k+1]
            end
        end
        return X
    end
                     
end

function AbstractDAQs.daqread(dev::EnvConds)
    E,rate = dev.server["read"]()
    X = parse_response(E)
    
    return MeasData{Matrix{Float64}}(devname(dev), devtype(dev),
                                     dev.time, rate, X, dev.chanidx)
end

function AbstractDAQs.daqacquire(dev::EnvConds)
    dev.time = now()
    E,rate = dev.server["acquire"]()
    X = parse_response(E)
    return MeasData{Matrix{Float64}}(devname(dev), devtype(dev),
                                     dev.time, rate, X, dev.chanidx)
end


AbstractDAQs.isreading(dev::EnvConds) = dev.server["isacquiring"]()
AbstractDAQs.samplesread(dev::EnvConds) = dev.server["samplesread"]()
AbstractDAQs.daqstop(dev::EnvConds) = dev.server["stop"]()

readpressure(dev::EnvConds) = dev.server["press"]()
readpresstemp(dev::EnvConds) = dev.server["presstemp"]()
readhumidity(dev::EnvConds) = dev.server["humidity"]()
readhumtemp(dev::EnvConds) = dev.server["humtemp"]()
readtemp(dev::EnvConds, i) = dev.server["temp"](i)

acquirechan(dev::EnvConds, ch::AbstractString) = dev.server["acquirechan"](ch)

daqclear(dev::EnvConds) = dev.server["clear"]()
daqstatus(dev::EnvConds) = dev.server["status"]()


end


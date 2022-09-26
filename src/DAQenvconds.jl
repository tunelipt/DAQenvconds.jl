module DAQenvconds

using PyCall
using DAQCore
import Dates: DateTime, now
import DataStructures: OrderedDict
export EnvConds, daqconfigdev, daqconfig, daqstop, daqacquire
export daqstart, daqread, samplesread, isreading
export daqchannels, numchannels, devname, devtype
export readpressure, readpresstemp, readhumidity, readhumtemp, readtemp
export daqclear, daqstatus

mutable struct EnvConds <: AbstractInputDev
    devname::String
    ip::String
    port::Int32
    server::PyObject
    config::DaqConfig
    chans::DaqChannels
    time::DateTime
end

DAQCore.devtype(dev::EnvConds) = "EnvConds"

function EnvConds(devname, ip, port=9539)
    xmlrpc = pyimport("xmlrpc.client")
    server = xmlrpc.ServerProxy("http://$ip:$port")
    config = DaqConfig(ip=ip, port=port, model="EnvConds")
    
    channames = server["channels"]()
    chans = DaqChannels(devname, "EnvConds", channames)
    fparam!(config, "time", server["daqtime"]())
    
    EnvConds(devname, ip, port, server, config,
             chans,  now())
end


function DAQCore.daqaddinput(dev::EnvConds, chans::AbstractVector{<:String})
    achans = dev.server["availablechannels"]()

    for ch in chans
        if ch ∉ achans
            error("Channel $ch not available!")
        end
    end

    dev.server["addinput"](chans)
    channames = server["channels"]()
    chans = DaqChannels(devname, "EnvConds", channames)
    
    return
    
end

function DAQCore.daqaddinput(dev::EnvConds, chans::AbstractVector{<:Integer})
    achans = dev.server["availablechannels"]()
    cmin, cmax = extrema(chans)
    
    if cmin < 1 || cmax > length(achans)
        error("Channel numbers should be between 1 and $(length(achans))!")
    end
    
    schans = achans[chans]
    
    dev.server["addinput"](schans)
    chans = DaqChannels(devname, "EnvConds", schans)
    
    return
    
end

DAQCore.daqconfigdev(dev::EnvConds; time=1) = dev.server["daqtime"](time)

DAQCore.daqconfig(dev::EnvConds; time=1) = dev.server["daqtime"](time)


function DAQCore.daqstart(dev::EnvConds)
    dev.time = now()
    dev.server["start"]()
end

DAQCore.daqchannels(dev::EnvConds) = daqchannels(dev.chans)

DAQCore.numchannels(dev::EnvConds) = numchannels(dev.chans)


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

function DAQCore.daqread(dev::EnvConds)
    E,rate = dev.server["read"]()
    X = parse_response(E)
    sampling = DaqSamplingRate(rate, size(X,2), dev.time)
    return MeasData(devname(dev), devtype(dev), sampling, X, dev.chans)
end

function DAQCore.daqacquire(dev::EnvConds)
    dev.time = now()
    E,rate = dev.server["acquire"]()
    X = parse_response(E)
    sampling = DaqSamplingRate(rate, size(X,2), dev.time)
    return MeasData(devname(dev), devtype(dev), sampling, X, dev.chans)
end


DAQCore.isreading(dev::EnvConds) = dev.server["isacquiring"]()
DAQCore.samplesread(dev::EnvConds) = dev.server["samplesread"]()
DAQCore.daqstop(dev::EnvConds) = dev.server["stop"]()

readpressure(dev::EnvConds) = dev.server["press"]()
readpresstemp(dev::EnvConds) = dev.server["presstemp"]()
readhumidity(dev::EnvConds) = dev.server["humidity"]()
readhumtemp(dev::EnvConds) = dev.server["humtemp"]()
readtemp(dev::EnvConds, i) = dev.server["temp"](i)

acquirechan(dev::EnvConds, ch::AbstractString) = dev.server["acquirechan"](ch)

daqclear(dev::EnvConds) = dev.server["clear"]()
daqstatus(dev::EnvConds) = dev.server["status"]()


end


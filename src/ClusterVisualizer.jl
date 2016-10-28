module ClusterVisualizer
using GLWindow, GLVisualize, GeometryTypes, GLAbstraction, Colors
import Combinatorics

abstract ClusterMetric

type IntraClusterDistance <: ClusterMetric
	distance::Array{Float64,2}
end

type InterClusterDistance <: ClusterMetric
	distance::Array{Float64,2}
end

function InterClusterDistance(X::Array{Float64,3}, labels::Array{Int64,1})
	ndims, ntrials, nbins = size(X)
	classes = unique(labels)
	sort!(classes)
	nclasses = length(classes)
	#compute cluster means
	centroids = zeros(ndims,nclasses,nbins)
	for (i,l) in enumerate(classes)
		_idx = find(x->x==l, labels)
		centroids[:,i,:] = mean(X[:,_idx,:],2)
	end
	distance = zeros(binomial(nclasses,2),nbins)
	k = 1
	for (c1, c2) in Combinatorics.combinations(1:nclasses,2)
		distance[k,:] = sumabs2(centroids[:,c1,:] .- centroids[:,c2,:],1)
		k += 1
	end
	InterClusterDistance(distance)
end

function IntraClusterDistance(X::Array{Float64,3}, labels::Array{Int64,1})
	ndims, ntrials, nbins = size(X)
	if isempty(labels)
		labels = fill(1,ntrials)
	end
	classes = unique(labels)
	sort!(classes)
	nclasses = length(classes)
	distances = zeros(nclasses,nbins)
	for (i,l) in enumerate(classes)
		_idx = find(x->x==l, labels)
		for (p1,p2) in Combinatorics.combinations(_idx,2)
			distances[i,:] += sumabs2(X[:,p1,:] .- X[:,p2,:],1)'
		end
		distances[i,:] ./= binomial(length(_idx),2)
	end
	IntraClusterDistance(distances)
end

IntraClusterDistance(X) = IntraClusterDistance(X, fill(1, size(X,2)))

function animate_clusters{T<:ClusterMetric}(X::Array{Float64,3}, labels=Int64[], fps=60.0;metric::Nullable{T}=Nullable{IntraClusterDistance}())
	ndims, npoints,nbins = size(X)
	#compute size of cluster
	if isnull(metric)
		intra = mean(T(X, labels).distance,1)
	else
		intra = mean(get(metric).distance,1)
	end
	if isempty(labels)
		colors = Array(Colors.RGBA{Float32},npoints)
		for i in 1:npoints
			r,g,b = rand(Float32, 3)
			colors[i] = RGBA(r,g,b,1.0f0)
		end
	else
		classes = unique(labels)
		class_colors = distinguishable_colors(length(classes), colorant"red")
		colors = class_colors[labels]
	end
	
	#setup windows
	window = glscreen()
	yhalf(r)  = SimpleRectangle(r.x, r.y, r.w, div(r.h,3))
	yhalf2(r) = SimpleRectangle(r.x, div(r.h,3), r.w, 2*div(r.h,3))

	screen2D = Screen(
		window, name=:screen2D,
		area=const_lift(yhalf, window.area)
	)

	screen3D = Screen(
		window, name=:screen3D,
		area=const_lift(yhalf2, window.area)
	)
	res = widths(screen2D)
	h = res[2]-40 #margins
	timesignal = loop(1:nbins,fps)
	Δt = (res[1]-20)/nbins
	#create 2d points
	mi,mx = extrema(intra)
	_trace = [Point2f0(10.0+(i-1)*Δt, h*(intra[i]-mi)/(mx-mi)+20) for i in 1:nbins]
	#create vertical line
	_vline = map(timesignal) do tt
		[Point2f0(10+(tt-1)*Δt,_x) for _x in linspace(20,h,10)]
	end

	#create model
	centroid = -mean(X, (2,3))[:]
	translation = translationmatrix(Vec3f0(centroid...))
	pm1,pm2,pm3 = extrema(X, (2,3))
	doscale = scalematrix(Vec3f0(1.0/(pm1[2]-pm1[1]), 1.0/(pm2[2]-pm2[1]), 1.0/(pm3[2]-pm3[1])))
	model = doscale*translation
	#create 3D points
	points = map(timesignal) do tt
		[Point3f0(X[1,i,tt], X[2,i,tt], X[3,i,tt]) for i in 1:npoints]
	end
	_view(visualize(_trace, :lines, color=RGBA(0.0, 0.0, 1.0, 1.0)),screen2D)
	_view(visualize(_vline, :lines, color=RGBA(1.0, 0.0, 0.0, 1.0)), screen2D)
	_view(visualize((Circle, points), color=colors,model=model,scale=Vec3f0(0.01)), screen3D, camera=:perspective)
	renderloop(window)
	nothing
end

end #module
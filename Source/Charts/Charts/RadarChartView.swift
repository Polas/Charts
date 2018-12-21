//
//  RadarChartView.swift
//  Charts
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

import Foundation
import CoreGraphics


/// Implementation of the RadarChart, a "spidernet"-like chart. It works best
/// when displaying 5-10 entries per DataSet.
open class RadarChartView: PieRadarChartViewBase
{
    /// width of the web lines that come from the center.
    @objc open var webLineWidth = CGFloat(1.5)
    
    /// width of the web lines that are in between the lines coming from the center
    @objc open var innerWebLineWidth = CGFloat(0.75)
    
    /// color for the web lines that come from the center
    @objc open var webColors = [NSUIColor(red: 122/255.0, green: 122/255.0, blue: 122.0/255.0, alpha: 1.0)]
    
    /// color for the web lines in between the lines that come from the center.
    @objc open var innerWebColor = NSUIColor(red: 122/255.0, green: 122/255.0, blue: 122.0/255.0, alpha: 1.0)
    
    /// transparency the grid is drawn with (0.0 - 1.0)
    @objc open var webAlpha: CGFloat = 150.0 / 255.0
    
    /// flag indicating if the web lines should be drawn or not
    @objc open var drawWeb = true
    
    /// modulus that determines how many labels and web-lines are skipped before the next is drawn
    private var _skipWebLineCount = 0
    
    /// the object reprsenting the y-axis labels
    private var _yAxis: YAxis!
    
    internal var _yAxisRenderer: YAxisRendererRadarChart!
    internal var _xAxisRenderer: XAxisRendererRadarChart!
    
    /// if true, the hole inside the chart will be drawn
    private var _drawHoleEnabled = true
    
    private var _holeColor: NSUIColor? = NSUIColor.white
    
    /// indicates the size of the hole in the center of the piechart
    ///
    /// **default**: `0.5`
    private var _holeRadiusPercent = CGFloat(0.5)
    
    public override init(frame: CGRect)
    {
        super.init(frame: frame)
    }
    
    public required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
    }
    
    open override func initialize()
    {
        super.initialize()
        
        _yAxis = YAxis(position: .left)
        
        renderer = RadarChartRenderer(chart: self, animator: _animator, viewPortHandler: _viewPortHandler)
        
        _yAxisRenderer = YAxisRendererRadarChart(viewPortHandler: _viewPortHandler, yAxis: _yAxis, chart: self)
        _xAxisRenderer = XAxisRendererRadarChart(viewPortHandler: _viewPortHandler, xAxis: _xAxis, chart: self)
        
        self.highlighter = RadarHighlighter(chart: self)
    }

    internal override func calcMinMax()
    {
        super.calcMinMax()
        
        guard let data = _data else { return }
        
        _yAxis.calculate(min: data.getYMin(axis: .left), max: data.getYMax(axis: .left))
        _xAxis.calculate(min: 0.0, max: Double(data.maxEntryCountSet?.entryCount ?? 0))
    }
    
    open override func notifyDataSetChanged()
    {
        calcMinMax()

        _yAxisRenderer?.computeAxis(min: _yAxis._axisMinimum, max: _yAxis._axisMaximum, inverted: _yAxis.isInverted)
        _xAxisRenderer?.computeAxis(min: _xAxis._axisMinimum, max: _xAxis._axisMaximum, inverted: false)
        
        if let data = _data,
            let legend = _legend,
            !legend.isLegendCustom
        {
            legendRenderer?.computeLegend(data: data)
        }
        
        calculateOffsets()
        
        setNeedsDisplay()
    }
    
    open override func draw(_ rect: CGRect)
    {
        super.draw(rect)

        guard data != nil, let renderer = renderer else { return }
        
        let optionalContext = NSUIGraphicsGetCurrentContext()
        guard let context = optionalContext else { return }
        
        
        if drawWeb
        {
            renderer.drawExtras(context: context)
        }
        
        if _yAxis.isEnabled && _yAxis.isDrawLimitLinesBehindDataEnabled
        {
            _yAxisRenderer.renderLimitLines(context: context)
        }

        renderer.drawData(context: context)

        if valuesToHighlight()
        {
            renderer.drawHighlighted(context: context, indices: _indicesToHighlight)
        }
        
        if _yAxis.isEnabled && !_yAxis.isDrawLimitLinesBehindDataEnabled
        {
            _yAxisRenderer.renderLimitLines(context: context)
        }
        
        _yAxisRenderer.renderAxisLabels(context: context)

        if _xAxis.isEnabled
        {
            _xAxisRenderer.computeAxis(min: _xAxis._axisMinimum, max: _xAxis._axisMaximum, inverted: false)
        }
        
        _xAxisRenderer?.renderAxisLabels(context: context)
        
        renderer.drawValues(context: context)
        

        legendRenderer.renderLegend(context: context)

        drawDescription(context: context)

        drawMarkers(context: context)
    }

    /// - returns: The factor that is needed to transform values into pixels.
    @objc open var factor: CGFloat
    {
        let content = _viewPortHandler.contentRect
        return min(content.width / 2.0, content.height / 2.0)
                / CGFloat(_yAxis.axisRange)
    }

    /// - returns: The angle that each slice in the radar chart occupies.
    @objc open var sliceAngle: CGFloat
    {
        return 360.0 / CGFloat(_data?.maxEntryCountSet?.entryCount ?? 0)
    }

    open override func indexForAngle(_ angle: CGFloat) -> Int
    {
        // take the current angle of the chart into consideration
        let a = (angle - self.rotationAngle).normalizedAngle
        
        let sliceAngle = self.sliceAngle
        
        let max = _data?.maxEntryCountSet?.entryCount ?? 0
        
        var index = 0
        
        for i in 0..<max
        {
            let referenceAngle = sliceAngle * CGFloat(i + 1) - sliceAngle / 2.0
            
            if referenceAngle > a
            {
                index = i
                break
            }
        }
        
        return index
    }

    /// - returns: The object that represents all y-labels of the RadarChart.
    @objc open var yAxis: YAxis
    {
        return _yAxis
    }

    /// Sets the number of web-lines that should be skipped on chart web before the next one is drawn. This targets the lines that come from the center of the RadarChart.
    /// if count = 1 -> 1 line is skipped in between
    @objc open var skipWebLineCount: Int
    {
        get
        {
            return _skipWebLineCount
        }
        set
        {
            _skipWebLineCount = max(0, newValue)
        }
    }
    
    internal override var requiredLegendOffset: CGFloat
    {
        return _legend.font.pointSize * 4.0
    }

    internal override var requiredBaseOffset: CGFloat
    {
        return _xAxis.isEnabled && _xAxis.isDrawLabelsEnabled ? _xAxis.labelRotatedWidth : 10.0
    }

    open override var radius: CGFloat
    {
        let content = _viewPortHandler.contentRect
        return min(content.width / 2.0, content.height / 2.0)
    }

    /// - returns: The maximum value this chart can display on it's y-axis.
    open override var chartYMax: Double { return _yAxis._axisMaximum }
    
    /// - returns: The minimum value this chart can display on it's y-axis.
    open override var chartYMin: Double { return _yAxis._axisMinimum }
    
    /// - returns: The range of y-values this chart can display.
    @objc open var yRange: Double { return _yAxis.axisRange }
    
    /// - returns: webLineHoleRadius - bullet at the end of web line
    @objc open var webLineHoleRadius: CGFloat { return webLineWidth * 3 }

    
    /// The color for the hole that is drawn in the center of the PieChart (if enabled).
    ///
    /// - note: Use holeTransparent with holeColor = nil to make the hole transparent.*
    @objc open var holeColor: NSUIColor?
        {
        get
        {
            return _holeColor
        }
        set
        {
            _holeColor = newValue
            setNeedsDisplay()
        }
    }
    
    /// `true` if the hole in the center of the pie-chart is set to be visible, `false` ifnot
    @objc open var drawHoleEnabled: Bool
        {
        get
        {
            return _drawHoleEnabled
        }
        set
        {
            _drawHoleEnabled = newValue
            setNeedsDisplay()
        }
    }
    
    /// - returns: `true` if the hole in the center of the pie-chart is set to be visible, `false` ifnot
    @objc open var isDrawHoleEnabled: Bool
        {
        get
        {
            return drawHoleEnabled
        }
    }
    
    /// the radius of the hole in the center of the piechart in percent of the maximum radius (max = the radius of the whole chart)
    ///
    /// **default**: 0.5 (50%) (half the pie)
    @objc open var holeRadiusPercent: CGFloat
        {
        get
        {
            return _holeRadiusPercent
        }
        set
        {
            _holeRadiusPercent = newValue
            setNeedsDisplay()
        }
    }
}

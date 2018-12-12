package io.polestar.view.charts;

import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.netkernel.layer0.nkf.INKFRequestContext;
import org.netkernel.layer0.nkf.INKFResponse;
import org.netkernel.layer0.nkf.NKFException;
import org.netkernel.mod.hds.IHDSDocument;
import org.netkernel.mod.hds.IHDSReader;
import org.netkernel.urii.impl.NetKernelException;

import io.polestar.api.IPolestarContext;
import io.polestar.api.IPolestarQuery;
import io.polestar.api.IPolestarQueryResultSet;
import io.polestar.api.QueryType;
import io.polestar.data.api.PolestarContext;
import io.polestar.view.sensors.SensorViewAccessor;

public class ChartSensorData
{
	private String mData;
	private double mMax;
	private double mMin;
	
	private static class SensorConfig
	{
		public String format;
		private double mScale;
		private double mOffset;
		
		public SensorConfig(String aFormat, double aScale, double aOffset)
		{	format=aFormat;
			mScale=aScale;
			mOffset=aOffset;
		}
		
		public double numericTransform(double v)
		{	return (v+mOffset)*mScale;
		}
		
		
	}
	
	
	public ChartSensorData(INKFRequestContext aContext, IHDSReader aOp, long aEnd, long aPeriod, long aSamplePeriod, String aDateFormat) throws NKFException
	{
		
		try
		{	IPolestarContext ctx=PolestarContext.createContext(aContext, null);
			IHDSReader config=aContext.source("active:polestarSensorConfig",IHDSDocument.class).getReader();
			
			//query sensors for data
			List<IHDSReader> sensors=aOp.getNodes("sensors/sensor");
			if (sensors.size()==0)
			{	mData="[]";
				return;
			}
			
			
			List<IPolestarQueryResultSet> resultSets=new ArrayList<IPolestarQueryResultSet>(sensors.size());
			List<SensorConfig> configs=new ArrayList<>(sensors.size());
			for (IHDSReader sensorNode : sensors)
			{
				String sensorIdRaw=(String)sensorNode.getFirstValue("id");
				String dname=(String)sensorNode.getFirstValueOrNull("dname");
				String sensorId;
				if (dname!=null && dname.indexOf('#')>=0)
				{	String fragment=dname.substring(dname.indexOf('#')+1);
					sensorId=sensorIdRaw+"#"+fragment;
				}
				else
				{	sensorId=sensorIdRaw;
				}
				String mergeAction=(String)sensorNode.getFirstValue("mergeAction");
				//System.out.println(sensorId+" "+mergeAction);
				QueryType qt=QueryType.valueOf(mergeAction.toUpperCase());
				IPolestarQuery q=ctx.createQuery(sensorId, qt);
				q.setEnd(aEnd);
				q.setStart(aEnd-aPeriod);
				q.setResultSetPeriod(aSamplePeriod);
				IPolestarQueryResultSet rs=(IPolestarQueryResultSet)q.execute();
				resultSets.add(rs);
				
				IHDSReader configNode=config.getFirstNodeOrNull("key('byId','"+sensorIdRaw+"')");
				if (configNode!=null)
				{
					String format=(String)configNode.getFirstValueOrNull("format");
									
					String valueMultiplyString=(String)sensorNode.getFirstValueOrNull("valueMultiply");
					String valueOffsetString=(String)sensorNode.getFirstValueOrNull("valueOffset");
					double scale=valueMultiplyString==null?1.0:Double.parseDouble(valueMultiplyString);
					double offset=valueOffsetString==null?0.0:Double.parseDouble(valueOffsetString);
					
					configs.add(new SensorConfig(format,scale,offset));
				}
				else
				{	configs.add(new SensorConfig(null,1,0));
				}
				
			}
			
			//create data transformation functions
			
			
			//format json
			DateFormat df=new SimpleDateFormat(aDateFormat);
			StringBuilder sb=new StringBuilder(4096);
			IPolestarQueryResultSet firstRS=resultSets.get(0);
			int rsLength=firstRS.size();
			
			sb.append("[ ");
			
			for (int i=0; i<rsLength; i++)
			{
				sb.append("[ ");
				
				long time=firstRS.getTimestamp(i);
				sb.append(time);
				sb.append(",'");
				sb.append(df.format(new Date(time)));
				sb.append("',");
				
				for (int j=0; j<resultSets.size(); j++)
				{
					if (j!=0)
					{	sb.append(", ");
					}
					Object value=resultSets.get(j).getValue(i);
					outputValue(sb, value, configs.get(j));
				}
				
				sb.append("],\n");
			}
			
			sb.append("]");
			mData=sb.toString();
			//System.out.println(mData);
			
			//compute max/min
			computeMaxMin(resultSets,aOp,configs);
			
			
		}
		catch (Exception e)
		{	throw new NKFException("Unhandled exception querying chart data", null, e);
		}
	}
	
	private void computeMaxMin(List<IPolestarQueryResultSet> aData, IHDSReader aOp, List<SensorConfig> aConfigs)
	{
		double max=Double.NEGATIVE_INFINITY;
		double min=Double.POSITIVE_INFINITY;
		
		
		int j=0;
		Set<Integer> stackedElements=new HashSet();
		for (IHDSReader sensorNode : aOp.getNodes("sensors/sensor"))
		{
			String stackedString=(String)sensorNode.getFirstValueOrNull("stacked");
			boolean stacked="true".equals(stackedString);
			if (stacked)
			{	stackedElements.add(j);
			}
			j++;
		}
		
		// non stacked elements
		int sensorIndex=0;
		for (IPolestarQueryResultSet rs : aData)
		{	SensorConfig config=aConfigs.get(sensorIndex);
			if (!stackedElements.contains(sensorIndex))
			{	for (int i=0; i<rs.size(); i++)
				{	Object v=rs.getValue(i);
					if (v instanceof Number)
					{	double d=((Number)v).doubleValue();
						d=config.numericTransform(d);
						if (d>max) max=d;
						if (d<min) min=d;
					}
				}
			}
			sensorIndex++;
		}
		
		//sum stacked elements
		if (stackedElements.size()>0)
		{
			IPolestarQueryResultSet rs0=aData.get(0);
			for (int i=0; i<rs0.size(); i++)
			{	
				double t=0; 
				sensorIndex=0;
				for (IPolestarQueryResultSet rs : aData)
				{	if (stackedElements.contains(sensorIndex))
					{
						Object v=rs.getValue(i);
						if (v instanceof Number)
						{	SensorConfig config=aConfigs.get(sensorIndex);
						
							double d=((Number)v).doubleValue();
							d=config.numericTransform(d);
							t+=d;
						}
					}
					sensorIndex++;
				}
				if (t>max) max=t;
				if (t<min) min=t;
			}
		
			//need proper baseline
			if (min>0.0) min=0.0;
		}		
		
		if (max==Double.NEGATIVE_INFINITY && min==Double.POSITIVE_INFINITY)
		{	max=1.0;
			min=0.0;
		}
		else if (max==Double.NEGATIVE_INFINITY)
		{	max=min+1.0;
		}
		else if (min==Double.POSITIVE_INFINITY)
		{	min=max-1.0;
		}
		else if (min==max)
		{	min-=0.5;
			max+=0.5f;
		}
		
		//System.out.println(min+" "+max);
		mMax=max;
		mMin=min;
		
	}
	
	private void outputValue(StringBuilder sb, Object v, SensorConfig config)
	{
		boolean needsQuotes=(v instanceof String);
		if (needsQuotes) sb.append("'");
		String format=config.format;
		if (v!=null && v instanceof Number)
		{
			double d=((Number)v).doubleValue();
			d=config.numericTransform(d);
			
			if (format==null) format="%.3f";
			sb.append(String.format(format, d));
		}
		else if (format==null || v==null)
		{	sb.append(v);
		}
		else
		{	String sf;
			try
			{	sf=v.toString(); //String.format(format, v);
			} catch (Exception e)
			{	sf=v.toString();
			}
			sb.append(sf);
		}
		
		if (needsQuotes) sb.append("'");
	}
	
	
	public double getMin()
	{	return mMin;
	}
	
	public double getMax()
	{	return mMax;
	}
	
	public String getJSON()
	{
		return mData;
		
	}
}

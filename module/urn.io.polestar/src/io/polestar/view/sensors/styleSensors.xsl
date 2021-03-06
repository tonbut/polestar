<?xml version="1.0" encoding="UTF-8" ?>
<!--
   Copyright 2015 1060 Research Ltd

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:nk="http://1060.org">
    <xsl:output method="xml"/>
    <xsl:param name="keywords"/>
    <xsl:param name="sort" nk:class="java.lang.String"></xsl:param>
    <xsl:param name="filtered" nk:class="java.lang.String"/>
	<xsl:param name="filter" nk:class="java.lang.String"></xsl:param>
    <xsl:template match="/">
    	<xsl:choose>
    		<xsl:when test="$filtered='true'">
    			<xsl:call-template name="filtered"/>
    		</xsl:when>
    		<xsl:when test="/error">
    			<xsl:call-template name="error"/>    			
    		</xsl:when>
    		<xsl:otherwise>
    			<xsl:call-template name="page"/>
    		</xsl:otherwise>
    	</xsl:choose>
    </xsl:template>
    
    <xsl:template name="error">
    	<div class="container top">
    		<div class="alert alert-info">
    			<p><xsl:value-of select="."/></p>
    			<p>See <a href="/polestar/help">help page</a> for more information on configuring sensors.
    			</p>
    		</div>
    	</div>
    </xsl:template>

    <xsl:template name="filtered">
    	<ul class="list-group" id="sensor-list" >
			<xsl:for-each select="/sensors/sensor">
				<xsl:call-template name="sensor"/>
			</xsl:for-each>
		</ul>
    </xsl:template>
    
    <xsl:template name="page">
    	<div class="container top">
            <script type="text/javascript" src="/polestar/pub/protovis-d3.2.js"></script>
    		<script><xsl:comment>
    			var updateTimeout;
                var showTickerFlag;
                sortOrder="default";
                
				$(function() {
					$("#filter").keyup( function(evt) {
						clearTimeout(updateTimeout);
						e=evt.which;
						if ( e==39 || e==37 || e==17 || e==18 || e==224) {
						//Ignore certain keys
						}
						else
						{	updateTimeout=setTimeout("doFilterUpdate()", 250);
						}
					});

                    $("#refresh").bind("click",function() {
                        doFilterUpdate();
                    });
                    $("#clear-filter").bind("click",function() {
                        doClearFilter();
                    });
                    
                    showTickerFlag=window.innerWidth&gt;768;
                    $("#toggle-stats").click( toggleTicker );
                    $("#sensor-info").click( function() {
                    	window.location.href = "/polestar/sensorinfo";
                    } );

                    if ($("#filter").val()!="")
                    {	doFilterUpdate();
                    }
                    else
                    {	showTicker();
                    }
				});	
                
                function toggleTicker()
                {   showTickerFlag=!showTickerFlag;
                    if (showTickerFlag)
                    {   showTicker();
                    }
                    else
                    {   $(".sensor-item > .row ").each(function(i,el){
                            var sensorId=$(el).parent().attr("sensorId");
                            $(el).children("div:nth-child(1)").removeClass("col-xs-6").addClass("col-xs-8");
                            $(el).children("div:nth-child(3)").removeClass("col-xs-3").addClass("col-xs-4");
                            $(el).children("div:nth-child(2)").remove();
                        });
                    }
                }
                
                function showTicker()
                {   if (showTickerFlag)
                    {   innerShowTicker();
                    }
                }

                function innerShowTicker()
                {
                	$(".sensor-item > .row ").each(function(i,el){
                        if ($(el).children().size()==2)
                        {	var sensorId=$(el).parent().attr("sensorId");
                        	$.get("/polestar/sensors/ticker/"+sensorId,function(d) {
                        	
                        		$(el).children("div:nth-child(1)").removeClass("col-xs-8").addClass("col-xs-6");
	                            $(el).children("div:nth-child(2)").removeClass("col-xs-4").addClass("col-xs-3");
	                            var di=$("&lt;div class='col-xs-3 ticker' id='s:"+sensorId+"'&gt;&lt;/div&gt;");
	                            
	                            var k=$(d);
	                            di.append(k);
	                            di.insertAfter($(el).children("div:nth-child(1)"));
                        	});
                        }
                    });
                    
                    
                	
                }
				
				function doClearFilter()
				{
					$("#filter").val("");
					doFilterUpdate();
				}
                
				function doFilterUpdate()
				{	var f=$("#filter").val();
					$.get("/polestar/sensors/filtered?f="+f+"&amp;sort="+sortOrder, function(d) {
						$("#sensor-list-container").empty();
						$("#sensor-list-container").html(d);
                        
                        showTicker();
                        
					},"html");
				}
				
				function onSort(order)
				{	sortOrder=order;
					doFilterUpdate();
					
				}
					
			</xsl:comment></script>
    	
    		<div class="list-group-item list-header">
    		
    			<div class="row">
    				<div class="col-sm-7">
    					<div class="input-group">
	                    	<xsl:variable name="count" select="count(/sensors/sensor)"/>
	    				    <input id="filter" type="text" placeholder="Filter list of {$count} sensors" class="form-control" value="">
	    				    	<xsl:attribute name="value"><xsl:value-of select="$filter"/></xsl:attribute>
	    				    </input>
	                        <span class="input-group-btn">
	                            <button id="clear-filter" class="btn btn-default"><span class="glyphicon glyphicon-remove"></span>&#160;</button>
	                        </span>
	                    </div>
    				</div>
    				<div class="col-sm-5">
 		   				<div class="btn-group">
						  <button style="margin-right: 0.5em;" type="button" class="btn btn-default dropdown-toggle" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
						    Sort by <span class="caret"></span>
						  </button>
						  <ul class="dropdown-menu">
						    <li><a onclick="onSort('default')">Default</a></li>
						    <li><a onclick="onSort('alpha')">Alphabetical</a></li>
						    <li><a onclick="onSort('lastUpd')">Last updated</a></li>
						    <li><a onclick="onSort('lastMod')">Last modified</a></li>
						    <li><a onclick="onSort('lastErr')">Last error</a></li>
						  </ul>
						</div>
                   		<button style="margin-left: 0.5em;" id="refresh" class="btn btn-default"><span class="glyphicon glyphicon-refresh"></span>&#160;</button>
                        <button style="margin-left: 0.5em;" id="sensor-info" class="btn btn-default"><span class="glyphicon glyphicon-info-sign"></span>&#160;</button>
                      	<button style="margin-left: 0.5em;" id="toggle-stats" class="btn btn-default"><span class="glyphicon glyphicon-stats"></span>&#160;</button>
                      	
                      	<span class="hidden-sm">
							<a class="btn btn-default" style="margin-left: 0.5em;" href="/polestar/sensors/backup" title="backup"><span class="glyphicon glyphicon-cloud-download"></span></a>
							<a class="btn btn-default" style="margin-left: 0.5em;" href="/polestar/sensors/restore" title="restore"><span class="glyphicon glyphicon-cloud-upload"></span></a>
						</span>
                      	
                      	
     				</div>
    			</div>
    	
                <div  id="sensor-keywords"> <!--class="hidden-xs"-->
                	<xsl:for-each select="$keywords/keywords/keyword">
                		<a href="sensors?filter={.}"><span class="label label-info"><xsl:value-of select="."/></span></a>
                		<xsl:text> </xsl:text>
                	</xsl:for-each>
                </div>
			</div>
    		<div id="sensor-list-container">
    			<ul class="list-group" id="sensor-list" >
					<xsl:for-each select="/sensors/sensor">
    					<xsl:call-template name="sensor"/>
    				</xsl:for-each>
    			</ul>
    		</div>
            <div id="scriptContainer"/>
	    	
		</div>
    </xsl:template>
    
    
    <xsl:template name="sensor">
    		<a href="/polestar/sensors/detail/{webId}">
		<li class="list-group-item sensor-item" sensorId="{id}">
			<xsl:choose>
				<xsl:when test="error">
					<xsl:attribute name="class">list-group-item sensor-item list-group-item-danger</xsl:attribute>
				</xsl:when>
			</xsl:choose>
			<div class="row">
				<div class="col-xs-8">
				<table style="width:100%">
					<tr>
						<td style="width: 0%">
							<div class="hidden-xs"><img class="icon" src="{defn/icon}" width="48" height="48"/></div>
							<div class="visible-xs"><img class="icon" src="{defn/icon}" width="24" height="24"/></div>
						</td>
						<td style="width: 100%">
							<div>
                                <span class="title"><xsl:value-of select="defn/name"/></span>
                                <span class="hidden-xs">
                                    <xsl:for-each select="keywordList/keyword">
                                        <xsl:text> </xsl:text>
                                        <span class="label label-info"><xsl:value-of select="."/></span>
                                    </xsl:for-each>
                                </span>
                            </div>
							<div class="changed">
								<span class="label label-default hidden-xs sensor-id"><xsl:value-of select="defn/id"/></span>
								<xsl:choose>
									<xsl:when test="$sort='lastErr'">
										Last Error <xsl:value-of select="lastErrorModifiedHuman"/>.
									</xsl:when>
									<xsl:otherwise>
										Changed <xsl:value-of select="lastModifiedHuman"/>
										<span class="hidden-xs">, last reading <xsl:value-of select="lastUpdatedHuman"/></span>.
									</xsl:otherwise>
								</xsl:choose>
								
							</div>
						</td>
					</tr>
				</table>
				</div>
				<div class="col-xs-4">
					<xsl:if test="string-length(valueHuman)&gt;10">
						<xsl:attribute name="class">col-xs-4 hidden-xs</xsl:attribute>
					</xsl:if>
                    <div style="float: right;">
	                    <div class="value">
	                        <xsl:choose>
	                            <xsl:when test="valueHTML">
	                                <xsl:value-of select="valueHTML" disable-output-escaping="yes" />
	                            </xsl:when>
	                            <xsl:when test="valueHuman='NULL'">
	                                Unknown
	                            </xsl:when>
	                            <xsl:otherwise>
	                                <xsl:value-of select="valueHuman"/>
	                                <xsl:text> </xsl:text>
	                                <xsl:value-of select="defn/units"/>
	                            </xsl:otherwise>
	                        </xsl:choose>
						</div>
						<xsl:choose>
							<xsl:when test="error">
								<div><xsl:value-of select="error"/></div>
							</xsl:when>
							<xsl:otherwise>
							</xsl:otherwise>
						</xsl:choose>
					</div>
				</div>
                
			</div>
				
		</li>
		</a>
    </xsl:template>
    
    
    
</xsl:stylesheet>
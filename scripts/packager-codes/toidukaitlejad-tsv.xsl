<?xml version="1.0" encoding="utf-8"?>

<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="text" encoding="UTF-8" />
  <xsl:strip-space elements="*" />
  <xsl:variable name="separator" select="'&#09;'" />

<xsl:template match="/v_toidukaitleja_avaandmed">
  <xsl:text>Käitleja identifikaator</xsl:text>
  <xsl:value-of select="$separator" />
  <xsl:text>Tegevuskoha identifikaator</xsl:text>
  <xsl:value-of select="$separator" />
  <xsl:text>Tunnusnumber</xsl:text>
  <xsl:value-of select="$separator" />
  <xsl:text>Tunnustatud</xsl:text>
  <xsl:value-of select="$separator" />
  <xsl:text>Käitleja registri- või isikukood</xsl:text>
  <xsl:value-of select="$separator" />
  <xsl:text>Käitleja aadress</xsl:text>
  <xsl:value-of select="$separator" />
  <xsl:text>Käitleja nimi</xsl:text>
  <xsl:value-of select="$separator" />
  <xsl:text>Tegevuskoha nimi</xsl:text>
  <xsl:value-of select="$separator" />
  <xsl:text>Põhikäitlemisvaldkond</xsl:text>
  <xsl:value-of select="$separator" />
  <xsl:text>Tegevuskoha maakond</xsl:text>
  <xsl:value-of select="$separator" />
  <xsl:text>Tegevuskoha aadress</xsl:text>
  <xsl:value-of select="$separator" />
  <xsl:text>lat</xsl:text>
  <xsl:value-of select="$separator" />
  <xsl:text>lng</xsl:text>
  <xsl:text>&#xa;</xsl:text>

  <xsl:apply-templates select="./row[tunnustatud = 'true' and ./tunnusnumber/node() and ./tunnusnumber != '----']">
    <xsl:sort select="tunnusnumber"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="row">
  <xsl:for-each select="child::*">
    <xsl:value-of select="normalize-space(.)"/>
    <xsl:if test="position() != last()">
      <xsl:value-of select="$separator" />
    </xsl:if>
    <xsl:if test="position() = last()">
      <xsl:text>&#xa;</xsl:text>
    </xsl:if>
  </xsl:for-each>
</xsl:template>

</xsl:stylesheet>
